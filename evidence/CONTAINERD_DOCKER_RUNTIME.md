# Containerd & Docker Runtime Audit

## 1. Docker Engine Information & Storage Driver

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

## 2. Containerd Sockets & Image Cache

`sudo ls /run/containerd/`:

```text
containerd.sock
containerd.sock.ttrpc
io.containerd.grpc.v1.cri
io.containerd.mount-manager.v1.bolt
io.containerd.runtime.v2.task
io.containerd.sandbox.controller.v1.shim
```

`sudo ctr images list`:
No cached images present in default containerd namespace (`REF TYPE DIGEST SIZE PLATFORMS LABELS`).

## 3. Backing Filesystem & Overlay Mounting

Mount info (`/proc/self/mountinfo | grep -E 'overlay|vdb'`):

```text
/dev/vdb on /rom/overlay (ext4, rw, relatime)
overlayfs:/overlay/root on / (overlay, rw, noatime, lowerdir=/, upperdir=/overlay/root, workdir=/overlay/work, uuid=on)
```

The Docker overlayfs storage driver operates on top of the VM's main OverlayFS lower/upper mount layer backed by `/dev/vdb`.
