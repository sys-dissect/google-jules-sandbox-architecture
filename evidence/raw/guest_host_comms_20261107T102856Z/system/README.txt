# System provenance snapshot
captured: 2026-11-07T10:52:35Z

captured_utc=2026-11-07T10:52:15Z
Linux devbox 6.8.0 #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux

console=ttyS0 reboot=k panic=1 pci=off init=/usr/sbin/overlay-init ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999 pci=off root=/dev/vda ro virtio_mmio.device=4K@0xc0001000:5 virtio_mmio.device=4K@0xc0002000:6 virtio_mmio.device=4K@0xc0003000:7 virtio_mmio.device=4K@0xc0004000:8

Linux version 6.8.0 (feyu@feyu-encarta.c.googlers.com) (gcc (Debian 15.2.0-3) 15.2.0, GNU ld (GNU Binutils for Debian) 2.45) #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026

kvm
 Static hostname: devbox
       Icon name: computer-vm
         Chassis: vm 🖴
      Machine ID: 58bffcf38f8d4939bd3e07b2ea187369
         Boot ID: 368a2f928fdb4f8189931ac81a2e3759
  Virtualization: kvm
Operating System: Ubuntu 24.04.4 LTS
          Kernel: Linux 6.8.0
    Architecture: x86-64

--- provenance ---
PRETTY_NAME="Ubuntu 24.04.4 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.4 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo

rootfs-20260306-162806.img
202610

build_name: ubuntu-oci:minimized
serial: 20260210.1
