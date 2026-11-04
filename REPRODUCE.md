# LOCAL REPRODUCTION BLUEPRINT: BUILDING A GOOGLE JULES DEVBOX

**Target Audience:** Systems Researchers, Infrastructure Engineers, Security Auditors
**Objective:** Locally reconstruct an identical AWS Firecracker microVM execution environment replicating Google Jules's virtualization, storage overlay, and VSOCK orchestration stack.

---

## 1. Prerequisites & Host Environment

Ensure the host machine is running Linux on bare-metal or inside a nested-virtualization-capable VM with KVM access:

```bash
# Verify KVM availability
ls -l /dev/kvm
# Ensure current user has KVM permissions
sudo chmod 666 /dev/kvm

# Install host utilities
sudo apt-get update && sudo apt-get install -y \
    curl \
    socat \
    squashfs-tools \
    e2fsprogs \
    docker.io \
    bridge-utils \
    iptables
```

Download the official AWS Firecracker binary:
```bash
FIRECRACKER_VERSION="v1.7.0"
curl -L https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/firecracker-${FIRECRACKER_VERSION}-x86_64.tgz | tar -xz
sudo mv release-${FIRECRACKER_VERSION}-x86_64/firecracker-*-x86_64 /usr/local/bin/firecracker
sudo mv release-${FIRECRACKER_VERSION}-x86_64/jailer-*-x86_64 /usr/local/bin/jailer
```

---

## 2. Minimal Linux Kernel Compilation (x86_64, Virtio-MMIO, No PCI)

Google Jules boots with `pci=off` and device enumeration over fixed Virtio-MMIO addresses. Build a compatible Linux 6.8 kernel:

```bash
# Clone Linux 6.8 source
git clone --depth 1 --branch v6.8 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux-6.8
cd linux-6.8

# Start with minimal x86_64 defconfig
make x86_64_defconfig

# Enable required kernel configs (or merge evidence/raw_telemetry/final_pass/kernel_config.txt)
scripts/config --enable CONFIG_VIRTIO
scripts/config --enable CONFIG_VIRTIO_MMIO
scripts/config --enable CONFIG_VIRTIO_MMIO_CMDLINE_DEVICES
scripts/config --enable CONFIG_VIRTIO_BLK
scripts/config --enable CONFIG_VIRTIO_NET
scripts/config --enable CONFIG_VIRTIO_VSOCKETS
scripts/config --enable CONFIG_OVERLAY_FS
scripts/config --enable CONFIG_SQUASHFS
scripts/config --enable CONFIG_SQUASHFS_XZ
scripts/config --enable CONFIG_EXT4_FS
scripts/config --enable CONFIG_IP_PNP
scripts/config --enable CONFIG_IP_PNP_STATIC
scripts/config --disable CONFIG_PCI

# Compile uncompressed kernel binary (vmlinux) for Firecracker
make -j$(nproc) vmlinux
cp vmlinux /tmp/jules-vmlinux
cd ..
```

---

## 3. Base Image Preparation (SquashFS 4.0 Golden Image)

Create an immutable rootfs using Docker Buildx and pack it into a SquashFS archive:

```bash
mkdir -p /tmp/jules-rootfs
cat << 'EOF' > /tmp/jules-rootfs/Dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install core packages and runtimes
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    sudo \
    openssh-server \
    socat \
    tmux \
    inotify-tools \
    python3 \
    python3-pip \
    pipx \
    golang-go \
    nodejs \
    npm \
    iproute2 \
    iptables \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Setup user jules with passwordless sudo
RUN useradd -m -s /bin/bash -u 1001 jules && \
    echo "jules ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jules && \
    chmod 0440 /etc/sudoers.d/jules

# Setup user swebot
RUN useradd -m -s /bin/bash swebot && \
    echo "swebot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/jules

# Create application workspace
RUN mkdir -p /app && chown -R jules:jules /app
EOF

# Build and export rootfs filesystem
docker build -t jules-base:local /tmp/jules-rootfs/
CONTAINER_ID=$(docker create jules-base:local)
mkdir -p /tmp/rootfs-dir
docker export ${CONTAINER_ID} | tar -x -C /tmp/rootfs-dir
docker rm ${CONTAINER_ID}
```

### Install Custom `/usr/sbin/overlay-init`

Write Google's verified pivot init script inside the rootfs:

```bash
cat << 'EOF' | sudo tee /tmp/rootfs-dir/usr/sbin/overlay-init
#!/bin/sh
# Google Jules Root Pivot Init Script
/bin/mount /dev/vdb /overlay
mkdir -p /overlay/root /overlay/work /overlay/root/rom

/bin/mount \
    -o noatime,lowerdir=/,upperdir=/overlay/root,workdir=/overlay/work \
    -t overlay "overlayfs:/overlay/root" /merged

/usr/sbin/pivot_root /merged /merged/rom
rmdir /overlay /merged
exec /usr/sbin/init "$@"
EOF

sudo chmod +x /tmp/rootfs-dir/usr/sbin/overlay-init
```

### Install Systemd Unit Files

```bash
# 1. VSOCK SSH Relay Unit
cat << 'EOF' | sudo tee /tmp/rootfs-dir/etc/systemd/system/devbox-ssh-over-vsock.service
[Unit]
Description=Bridge AF_VSOCK port 22 to localhost SSH
After=sshd.service

[Service]
Type=simple
ExecStart=/usr/bin/socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 2. tmpfs Optimization for /var/lib/systemd
cat << 'EOF' | sudo tee /tmp/rootfs-dir/etc/systemd/system/var-lib-systemd.mount
[Unit]
Description=Mount tmpfs on /var/lib/systemd
Before=local-fs.target

[Mount]
What=tmpfs
Where=/var/lib/systemd
Type=tmpfs
Options=rw,nosuid,nodev,size=4G,nr_inodes=10240

[Install]
WantedBy=multi-user.target
EOF

# Enable units
sudo chroot /tmp/rootfs-dir systemctl enable devbox-ssh-over-vsock.service
sudo chroot /tmp/rootfs-dir systemctl enable var-lib-systemd.mount
```

### Compress into SquashFS Golden Image
```bash
mksquashfs /tmp/rootfs-dir /tmp/jules-base.squashfs -comp xz -b 128K -noappend
```

---

## 4. Scratch Overlay Disk Preparation (100 GiB Sparse ext4)

Create the sparse copy-on-write overlay disk:

```bash
# Create 100 GiB sparse file
truncate -s 100G /tmp/jules-scratch.ext4
mkfs.ext4 -F /tmp/jules-scratch.ext4
```

---

## 5. Host Network & Git Proxy Setup

Configure the host tap interface and routing:

```bash
# Setup host TAP device
sudo ip tuntap add dev tap0 mode tap
sudo ip addr add 192.168.0.1/24 dev tap0
sudo ip link set tap0 up

# Enable NAT IP forwarding on host
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i tap0 -o eth0 -j ACCEPT
```

### Run Transparent Host Git Proxy (`devbox-gateway.internal:8080`)

Launch a lightweight Python reverse proxy on port 8080:

```python
#!/usr/bin/env python3
# host_git_proxy.py
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request

class GitProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.proxy_request()

    def do_POST(self):
        self.proxy_request()

    def proxy_request(self):
        # Forward request upstream to github.com and inject OAuth credentials
        target_url = "https://github.com" + self.path
        # Upstream proxy logic here...
        self.send_response(200)
        self.end_headers()

if __name__ == '__main__':
    server = HTTPServer(('192.168.0.1', 8080), GitProxyHandler)
    print("Host Git Proxy listening on 192.168.0.1:8080")
    server.serve_forever()
```

---

## 6. Firecracker MicroVM JSON Specification

Create the complete Firecracker microVM configuration `vm_config.json`:

```json
{
  "boot-source": {
    "kernel_image_path": "/tmp/jules-vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off init=/usr/sbin/overlay-init ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999 pci=off root=/dev/vda ro virtio_mmio.device=4K@0xc0001000:5 virtio_mmio.device=4K@0xc0002000:6 virtio_mmio.device=4K@0xc0003000:7 virtio_mmio.device=4K@0xc0004000:8"
  },
  "drives": [
    {
      "drive_id": "vda",
      "path_on_host": "/tmp/jules-base.squashfs",
      "is_root_device": true,
      "is_read_only": true
    },
    {
      "drive_id": "vdb",
      "path_on_host": "/tmp/jules-scratch.ext4",
      "is_root_device": false,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
    {
      "iface_id": "net1",
      "guest_mac": "06:00:c0:a8:00:02",
      "host_dev_name": "tap0"
    }
  ],
  "machine-config": {
    "vcpu_count": 4,
    "mem_size_mib": 8192,
    "smt": false
  },
  "vsock": {
    "vsock_id": "vsock0",
    "guest_cid": 123,
    "uds_path": "/tmp/firecracker-vsock.sock"
  }
}
```

---

## 7. Starting the MicroVM & Connecting via VSOCK SSH

Start Firecracker:
```bash
# Remove stale socket
rm -f /tmp/firecracker.socket /tmp/firecracker-vsock.sock

# Spawn Firecracker with API socket
firecracker --api-sock /tmp/firecracker.socket --config-file vm_config.json
```

### Host-Side VSOCK SSH Bridge
Connect into the guest using `socat` over the Unix domain socket corresponding to Guest CID 123:

```bash
# Bridge host TCP port 2222 to guest VSOCK port 22
socat TCP-LISTEN:2222,fork,reuseaddr UNIX-CONNECT:/tmp/firecracker-vsock.sock &

# Connect into the microVM
ssh -p 2222 jules@127.0.0.1
```

Once inside, you will have a live, authentic Google Jules execution environment with the identical storage overlay, Virtio-MMIO devices, and VSOCK orchestration harness.
