1. DMI & Hypervisor: tail -n +1 /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/product_version 2>/dev/null; cat /proc/cmdline
```
unknown
console=ttyS0 reboot=k panic=1 pci=off init=/usr/sbin/overlay-init ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999 pci=off root=/dev/vda ro virtio_mmio.device=4K@0xc0001000:5 virtio_mmio.device=4K@0xc0002000:6 virtio_mmio.device=4K@0xc0003000:7 virtio_mmio.device=4K@0xc0004000:8
```

2. CPU & PCI: lscpu | grep -E "Model name|Virtualization|Architecture|Vendor ID"; lspci -nnk
```
Architecture:                       x86_64
Vendor ID:                          GenuineIntel
Model name:                         Intel(R) Xeon(R) Processor @ 2.30GHz
Virtualization type:                full
run_checks_b.sh: line 15: lspci: command not found
unknown
```

3. Storage & Mounts: lsblk -f; cat /proc/mounts
```
NAME FSTYPE   FSVER LABEL   UUID                                 FSAVAIL FSUSE% MOUNTPOINTS
vda  squashfs 4.0                                                      0   100% /rom
vdb  ext4     1.0   overlay a9893320-d2ab-4aca-98ea-9a5954d46d7d   92.8G     0% /rom/overlay
/dev/root /rom squashfs ro,relatime,errors=continue 0 0
devtmpfs /rom/dev devtmpfs rw,relatime,size=4096k,nr_inodes=1018287,mode=755 0 0
/dev/vdb /rom/overlay ext4 rw,relatime 0 0
overlayfs:/overlay/root / overlay rw,noatime,lowerdir=/,upperdir=/overlay/root,workdir=/overlay/work,uuid=on 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
devtmpfs /dev devtmpfs rw,nosuid,size=4096k,nr_inodes=1018287,mode=755 0 0
tmpfs /dev/shm tmpfs rw,nosuid,nodev 0 0
devpts /dev/pts devpts rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000 0 0
tmpfs /run tmpfs rw,nosuid,nodev,size=1630024k,nr_inodes=819200,mode=755 0 0
tmpfs /run/lock tmpfs rw,nosuid,nodev,noexec,relatime,size=5120k 0 0
cgroup2 /sys/fs/cgroup cgroup2 rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot 0 0
bpf /sys/fs/bpf bpf rw,nosuid,nodev,noexec,relatime,mode=700 0 0
tmpfs /run/credentials/@system tmpfs ro,nosuid,nodev,noexec,relatime,nosymfollow,size=1024k,nr_inodes=1024,mode=700,noswap 0 0
systemd-1 /proc/sys/fs/binfmt_misc autofs rw,relatime,fd=32,pgrp=1,timeout=0,minproto=5,maxproto=5,direct 0 0
mqueue /dev/mqueue mqueue rw,nosuid,nodev,noexec,relatime 0 0
hugetlbfs /dev/hugepages hugetlbfs rw,nosuid,nodev,relatime,pagesize=2M 0 0
tmpfs /var/lib/systemd tmpfs rw,nosuid,nodev,size=4075060k,nr_inodes=10240 0 0
fusectl /sys/fs/fuse/connections fusectl rw,nosuid,nodev,noexec,relatime 0 0
binfmt_misc /proc/sys/fs/binfmt_misc binfmt_misc rw,nosuid,nodev,noexec,relatime 0 0
tmpfs /run/user/1001 tmpfs rw,nosuid,nodev,relatime,size=815008k,nr_inodes=203752,mode=700,uid=1001,gid=1001 0 0
```

4. Sockets & Network: ss -tulpn; ip route show; cat /etc/resolv.conf
```
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
tcp   LISTEN 0      0            0.0.0.0:22        0.0.0.0:*
tcp   LISTEN 0      0                  *:22              *:*
default via 192.168.0.1 dev eth0
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
192.168.0.0/24 dev eth0 proto kernel scope link src 192.168.0.2
nameserver 192.168.0.1
```

5. Docker execution test: docker run --rm alpine uname -a
```
Unable to find image 'alpine:latest' locally
latest: Pulling from library/alpine
e2de96513ba9: Pulling fs layer
6d0606d1815c: Download complete
e2de96513ba9: Download complete
797dd00a0fc7: Download complete
e2de96513ba9: Pull complete
Digest: sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6
Status: Downloaded newer image for alpine:latest
docker: Error response from daemon: failed to mount /tmp/containerd-mount497727966: mount source: "overlay", target: "/tmp/containerd-mount497727966", fstype: overlay, flags: 0, data: "workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/2/work,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/2/fs,lowerdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/1/fs,index=off", err: invalid argument

Run 'docker run --help' for more information
unknown
```
