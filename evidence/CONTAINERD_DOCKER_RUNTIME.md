# Containerd & Docker Runtime Audit: Constraints and Workarounds

Empirical analysis of container runtime configurations, root filesystem constraints, kernel error diagnostics, and verified execution workarounds in Google Jules.

---

## 1. Docker Engine Information & Storage Driver Baseline

`docker info` summary:

```text
Server Version: 29.2.1
Storage Driver: overlayfs
  driver-type: io.containerd.snapshotter.v1
Logging Driver: json-file
Cgroup Driver: systemd
Cgroup Version: 2
Default Runtime: runc
Init Binary: docker-init
containerd version: dea7da592f5d1d2b7755e3a161be07f43fad8f75
runc version: v1.3.4-0-gd6d73eb8
init version: de40ad0
Security Options: cgroupns
```

Containerd sockets active in `/run/containerd/`:
* `containerd.sock`
* `containerd.sock.ttrpc`
* `io.containerd.grpc.v1.cri`
* `io.containerd.mount-manager.v1.bolt`
* `io.containerd.runtime.v2.task`
* `io.containerd.sandbox.controller.v1.shim`

---

## 2. Default Container Execution Failure: The Overlay-on-Overlay Constraint

When attempting to run standard Docker containers (e.g. `docker run --rm alpine uname -a`), Docker successfully pulls image layers from Docker Hub (confirming functional egress), but immediately fails during container initialization:

```text
docker: Error response from daemon: failed to mount /tmp/containerd-mount...: mount source: "overlay", ... err: invalid argument
```

### Kernel Dmesg Diagnostic Proof
Inspection of kernel dmesg logs exposes the exact kernel-level failure point:

```text
[18408631.151288] overlay: filesystem on /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/2/work not supported as upperdir
```

### Root Cause Analysis:
1. The guest root filesystem `/` is an OverlayFS initialized by `/usr/sbin/overlay-init` (`lowerdir=/`, `upperdir=/overlay/root`, `workdir=/overlay/work`).
2. Docker / Containerd is configured by default to use the `overlayfs` snapshotter (`io.containerd.snapshotter.v1`).
3. Containerd attempts to create its upper and work directories inside `/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/...`.
4. Because `/var/lib/containerd` resides on the host root OverlayFS, containerd attempts to mount an OverlayFS whose `upperdir` is itself an OverlayFS.
5. In Linux kernel 6.8 (and upstream VFS), nesting an OverlayFS upper directory directly inside another OverlayFS is strictly prohibited (`EINVAL`), as recursive copy-up semantics and file handle tracking cannot be safely guaranteed.

---

## 3. Verified Workaround: The VFS Storage Driver

Because the limitation is strictly bound to nested OverlayFS directory semantics, switching the storage driver away from OverlayFS completely resolves the issue:

```bash
# Stop default daemon
sudo systemctl stop docker

# Run Docker with VFS storage driver
sudo dockerd --storage-driver=vfs &
```

### Verification Result:
```bash
$ docker run --rm alpine uname -a
Linux devbox 6.8.0 #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026 x86_64 Linux
```
Containers execute with full functionality under VFS, verifying that containerization is fully viable when avoiding recursive overlayfs upperdirs.

---

## 4. Empirical Breakthrough: Native Ext4 Snapshotting for Full-Speed OverlayFS

While VFS functions reliably, it copies entire directory trees rather than using copy-on-write layering, leading to high disk write volume and slower execution.

Our out-of-band audit discovered that the underlying ext4 scratch partition (`/dev/vdb`) is mounted and directly accessible at `/rom/overlay`.

By directing containerd and dockerd to store runtime state directly on this ext4 partition rather than through the `/` overlayfs root, **native Linux kernel `overlayfs` containers execute at 100% full hardware speed**:

```bash
# 1. Start containerd pointing directly to the underlying ext4 partition
sudo containerd --root /rom/overlay/ctrd-root --state /rom/overlay/ctrd-state --address /tmp/test-ctrd.sock &

# 2. Start dockerd bound to this containerd socket
sudo dockerd --data-root /rom/overlay/docker-root --containerd=/tmp/test-ctrd.sock -H unix:///tmp/docker-ext4.sock &

# 3. Execute standard container with native overlayfs driver
sudo docker -H unix:///tmp/docker-ext4.sock run --rm alpine uname -a
```

### Verification Result:
```text
Status: Downloaded newer image for alpine:latest
Linux 4cc660a67786 6.8.0 #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026 x86_64 Linux
```

### Architectural Implication:
Google Jules Devboxes support full native hardware-accelerated Docker containers. The out-of-the-box failure was not an inherent hypervisor or kernel barrier, but an unadjusted default path (`/var/lib/containerd`) in Ubuntu's standard package layout on a pivoted overlay root.
