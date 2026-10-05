1. Init script: cat /usr/sbin/overlay-init 2>/dev/null || file /usr/sbin/overlay-init
```
#!/bin/sh

# FIXME(feyu): using the label during init apparently doesn't work.
# Use /dev/vdb for now.
# /bin/mount /dev/disk/by-label/overlay /overlay

ls /dev/disk/by-label
/bin/mount /dev/vdb /overlay

mkdir -p /overlay/root /overlay/work /overlay/root/rom

/bin/mount \
    -o noatime,lowerdir=/,upperdir=/overlay/root,workdir=/overlay/work \
    -t overlay "overlayfs:/overlay/root" /merged

/usr/sbin/pivot_root /merged /merged/rom

# remove dirs for setting up the overlay from the new root
rmdir /overlay
rmdir /merged

exec /usr/sbin/init $@
```

2. VMM credential consumer: grep -rn "vmm.notify_socket" /etc/systemd/ /usr/lib/systemd/ /run/ 2>/dev/null || true
```
/run/devbox-session/default/command:12:echo "2. VMM credential consumer: grep -rn \"vmm.notify_socket\" /etc/systemd/ /usr/lib/systemd/ /run/ 2>/dev/null || true"
/run/devbox-session/default/command:14:grep -rn "vmm.notify_socket" /etc/systemd/ /usr/lib/systemd/ /run/ 2>/dev/null || echo "unknown"
unknown
```

3. MicroVM & Virtio dmesg: dmesg | grep -iE "hypervisor|virtio|kvm|overlay|acpi" | head -n 40; cat /proc/iomem | grep -i virtio
```
[    0.000000] Linux version 6.8.0 (feyu@feyu-encarta.c.googlers.com) (gcc (Debian 15.2.0-3) 15.2.0, GNU ld (GNU Binutils for Debian) 2.45) #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026
[    0.000000] Command line: console=ttyS0 reboot=k panic=1 pci=off init=/usr/sbin/overlay-init ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999 pci=off root=/dev/vda ro virtio_mmio.device=4K@0xc0001000:5 virtio_mmio.device=4K@0xc0002000:6 virtio_mmio.device=4K@0xc0003000:7 virtio_mmio.device=4K@0xc0004000:8
[    0.000000] DMI not present or invalid.
[    0.000000] Hypervisor detected: KVM
[    0.000000] kvm-clock: Using msrs 4b564d01 and 4b564d00
[    0.000001] kvm-clock: using sched offset of 72721302 cycles
[    0.000022] clocksource: kvm-clock: mask: 0xffffffffffffffff max_cycles: 0x1cd42e4dffb, max_idle_ns: 881590591483 ns
[    0.002522] ACPI: RSDP 0x00000000000E0000 000024 (v02 FIRECK)
[    0.002602] ACPI: XSDT 0x00000000000A024E 00003C (v01 FIRECK FCMVXSDT 00000000 FCAT 20240119)
[    0.002686] ACPI: FACP 0x00000000000A00A6 000114 (v06 FIRECK FCVMFADT 00000000 FCAT 20240119)
[    0.002751] ACPI: DSDT 0x000000000009FD6C 00033A (v02 FIRECK FCVMDSDT 00000000 FCAT 20240119)
[    0.002756] ACPI: APIC 0x00000000000A01BA 000058 (v06 FIRECK FCVMMADT 00000000 FCAT 20240119)
[    0.002761] ACPI: MCFG 0x00000000000A0212 00003C (v01 FIRECK FCMVMCFG 00000000 FCAT 20240119)
[    0.762632] kvm-guest: APIC: eoi() replaced with kvm_guest_apic_eoi_write()
[    0.762895] kvm-guest: KVM setup pv remote TLB flush
[    0.762933] kvm-guest: setup PV sched yield
[    0.763152] Booting paravirtualized kernel on KVM
[    0.775992] kvm-guest: PV spinlocks enabled
[    0.776001] Kernel command line: console=ttyS0 reboot=k panic=1 pci=off init=/usr/sbin/overlay-init ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999 pci=off root=/dev/vda ro virtio_mmio.device=4K@0xc0001000:5 virtio_mmio.device=4K@0xc0002000:6 virtio_mmio.device=4K@0xc0003000:7 virtio_mmio.device=4K@0xc0004000:8
[    1.742269] kvm-guest: APIC: send_IPI_mask() replaced with kvm_send_ipi_mask()
[    1.746611] kvm-guest: APIC: send_IPI_mask_allbutself() replaced with kvm_send_ipi_mask_allbutself()
[    1.752081] kvm-guest: setup PV IPIs
[    1.901313] clocksource: Switched to clocksource kvm-clock
[    2.016222] virtio-mmio: Registering device virtio-mmio.0 at 0xc0001000-0xc0001fff, IRQ 5.
[    2.021547] virtio-mmio: Registering device virtio-mmio.1 at 0xc0002000-0xc0002fff, IRQ 6.
[    2.026848] virtio-mmio: Registering device virtio-mmio.2 at 0xc0003000-0xc0003fff, IRQ 7.
[    2.032204] virtio-mmio: Registering device virtio-mmio.3 at 0xc0004000-0xc0004fff, IRQ 8.
[    2.078252] virtio-mmio virtio-mmio.0: can't request region for resource [mem 0xc0001000-0xc0001fff]
[    2.083761] virtio-mmio: probe of virtio-mmio.0 failed with error -16
[    2.087642] virtio-mmio virtio-mmio.1: can't request region for resource [mem 0xc0002000-0xc0002fff]
[    2.093065] virtio-mmio: probe of virtio-mmio.1 failed with error -16
[    2.096980] virtio-mmio virtio-mmio.2: can't request region for resource [mem 0xc0003000-0xc0003fff]
[    2.102395] virtio-mmio: probe of virtio-mmio.2 failed with error -16
[    2.106264] virtio-mmio virtio-mmio.3: can't request region for resource [mem 0xc0004000-0xc0004fff]
[    2.111677] virtio-mmio: probe of virtio-mmio.3 failed with error -16
[    2.134967] virtio_blk virtio0: 1/0/0 default/read/poll queues
[    2.140210] virtio_blk virtio0: [vda] 9144320 512-byte logical blocks (4.68 GB/4.36 GiB)
[    2.146606] virtio_blk virtio1: 1/0/0 default/read/poll queues
[    2.151706] virtio_blk virtio1: [vdb] 209715200 512-byte logical blocks (107 GB/100 GiB)
[    2.767398] Run /usr/sbin/overlay-init as init process
[    2.769136]     /usr/sbin/overlay-init
[    3.618608] systemd[1]: Detected virtualization kvm.
[18408631.151288] overlay: filesystem on /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/2/work not supported as upperdir
00000000-00000000 : virtio-mmio.0
00000000-00000000 : virtio-mmio.1
00000000-00000000 : virtio-mmio.2
00000000-00000000 : virtio-mmio.3
```

4. Cgroup Limits: tail -n +1 /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max 2>/dev/null || true
```
unknown
```

5. CPU Features: grep -m 1 "flags" /proc/cpuinfo
```
flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ss ht syscall nx pdpe1gb rdtscp lm constant_tsc rep_good nopl xtopology nonstop_tsc cpuid tsc_known_freq pni pclmulqdq ssse3 fma cx16 pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand hypervisor lahf_lm abm cpuid_fault pti ssbd ibrs ibpb stibp fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid xsaveopt arat umip md_clear arch_capabilities
```
