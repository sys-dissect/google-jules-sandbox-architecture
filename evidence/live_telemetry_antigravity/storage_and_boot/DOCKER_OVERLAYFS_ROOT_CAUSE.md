# Empirical Breakthrough: Resolving the Docker OverlayFS Failure

## 1. Context & The Initial Negative Result
In earlier audits, running standard Docker containers (`docker run --rm alpine uname -a`) failed with:
```text
docker: Error response from daemon: failed to mount /tmp/containerd-mount...: mount source: "overlay", ... err: invalid argument
```
Kernel dmesg confirmed:
```text
[20973843.613125] overlay: filesystem on /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/2/work not supported as upperdir
```
The initial hypothesis was that Docker could *only* run using the slow `vfs` storage driver (`dockerd --storage-driver=vfs`), which disables copy-on-write layering and causes severe disk write bloat.

---

## 2. The Architectural Root Cause
The root cause was **not** an inherent hypervisor or kernel restriction preventing container overlays in Firecracker.

The failure occurred because:
1. `/usr/lib/systemd/system/containerd.service` starts `containerd` with its default root path `/var/lib/containerd`.
2. `/var/lib/containerd` resides on `/`, which is mounted as an `overlayfs` uniting SquashFS `/rom` and ext4 `/dev/vdb`.
3. The Linux kernel explicitly prohibits using an `overlayfs` as an upper layer for another nested `overlayfs` (`EINVAL`).

---

## 3. The Verified Solution: Native Ext4 Snapshotting
Inspection of `/rom/overlay` reveals that `/dev/vdb` (raw ext4) is already directly accessible at `/rom/overlay`.

By configuring `containerd` and `dockerd` to store their root directories directly on the underlying ext4 filesystem rather than through the `/` overlay, native `overlayfs` container execution succeeds:

```bash
# 1. Start containerd pointing directly to the underlying ext4 scratch partition
sudo containerd --root /rom/overlay/ctrd-root --state /rom/overlay/ctrd-state --address /tmp/test-ctrd.sock &

# 2. Start dockerd bound to this containerd socket
sudo dockerd --data-root /rom/overlay/docker-root --containerd=/tmp/test-ctrd.sock -H unix:///tmp/docker-ext4.sock &

# 3. Execute standard container with native overlayfs driver
sudo docker -H unix:///tmp/docker-ext4.sock run --rm alpine uname -a
```

### Empirical Result:
```text
Status: Downloaded newer image for alpine:latest
Linux 4cc660a67786 6.8.0 #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026 x86_64 Linux
```

### Systems Implication:
Full-speed, hardware-accelerated OCI containers with native Linux kernel `overlayfs` snapshotting work inside Google Jules devboxes without falling back to `vfs`. The out-of-the-box failure was merely a configuration artifact of running standard Ubuntu systemd unit paths on a pivoted overlay root.
