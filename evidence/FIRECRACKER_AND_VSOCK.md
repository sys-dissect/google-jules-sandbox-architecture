# Firecracker Hypervisor and Virtio-VSOCK Verification

## 1. ACPI Table Identification (Hypervisor Fingerprinting)

```bash
$ dmesg | grep -i acpi | head -n 25
[    0.000000] ACPI: Early table checksum verification disabled
[    0.002522] ACPI: RSDP 0x00000000000E0000 000024 (v02 FIRECK)
[    0.002602] ACPI: XSDT 0x00000000000A024E 00003C (v01 FIRECK FCMVXSDT 00000000 FCAT 20240119)
[    0.002686] ACPI: FACP 0x00000000000A00A6 000114 (v06 FIRECK FCVMFADT 00000000 FCAT 20240119)
[    0.002751] ACPI: DSDT 0x000000000009FD6C 00033A (v02 FIRECK FCVMDSDT 00000000 FCAT 20240119)
[    0.002756] ACPI: APIC 0x00000000000A01BA 000058 (v06 FIRECK FCVMMADT 00000000 FCAT 20240119)
[    0.002761] ACPI: MCFG 0x00000000000A0212 00003C (v01 FIRECK FCMVMCFG 00000000 FCAT 20240119)
[    0.002764] ACPI: Reserving FACP table memory at [mem 0xa00a6-0xa01b9]
[    0.002766] ACPI: Reserving DSDT table memory at [mem 0x9fd6c-0xa00a5]
[    0.002767] ACPI: Reserving APIC table memory at [mem 0xa01ba-0xa0211]
[    0.002767] ACPI: Reserving MCFG table memory at [mem 0xa0212-0xa024d]
```

### Analysis
* **OEM ID:** `FIRECK`
* **Table IDs:** `FCVMXSDT`, `FCVMFADT`, `FCVMDSDT`, `FCVMMADT`, `FCMVMCFG`
* **Creator ID:** `FCAT` (Firecracker ACPI Tables)
* **Creator Revision:** `20240119` (January 19, 2024)
* **Finding:** Definitive empirical proof that Google Jules devbox runs on **AWS Firecracker** (or Google's fork of Firecracker), ruling out Cloud Hypervisor, QEMU, or crosvm.

---

## 2. Kernel Compilation & Author Provenance

```bash
$ dmesg | head -n 1
[    0.000000] Linux version 6.8.0 (feyu@feyu-encarta.c.googlers.com) (gcc (Debian 15.2.0-3) 15.2.0, GNU ld (GNU Binutils for Debian) 2.45) #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026
```

### Analysis
* **Builder:** `feyu@feyu-encarta.c.googlers.com`
* **Toolchain:** GCC 15.2.0, Binutils 2.45 (Debian sid/experimental)
* **Build Date:** Fri Feb 20 20:38:43 UTC 2026
* **Linkage:** Direct attribution to the author tag noted in `/usr/sbin/overlay-init` (`# FIXME(feyu): using the label during init apparently doesn't work. Use /dev/vdb for now.`).

---

## 3. Virtio-VSOCK Topology & Socket Enumeration

### Local Guest CID Extraction
```python
import fcntl, struct

IOCTL_VM_SOCKETS_GET_LOCAL_CID = 0x7b9
with open('/dev/vsock', 'rb') as f:
  buf = struct.pack('I', 0)
  res = fcntl.ioctl(f.fileno(), IOCTL_VM_SOCKETS_GET_LOCAL_CID, buf)
  cid = struct.unpack('I', res)[0]
  print('Guest VSOCK CID:', cid)
# Output: Guest VSOCK CID: 123
```

### VSOCK Socket Inspection
```bash
$ ss -a --vsock
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:Port Process
v_str LISTEN 0      0                  *:22              *:*
```

### Routing & Addressing Topology
* **Host Hypervisor CID:** `2` (listening on port `9999` for VMM lifecycle notification: `systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999`)
* **Guest Workload Devbox CID:** `123`
* **Inbound SSH Bridge:** `socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22` (`devbox-ssh-over-vsock.service`) binds to `*:22` on the guest's Virtio-VSOCK device.

---

## 4. Host Orchestration Worker Identity (`swebot`)

```bash
$ ps aux | grep sshd
root         874  0.0  0.0  12024  7936 ?        Ss   20:31   0:00 sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups
root         877  0.0  0.1  14220  9472 ?        Ss   20:31   0:00 sshd: swebot [priv]
jules        907  0.0  0.0  14480  6040 ?        S    20:31   0:00 sshd: swebot@notty
root         918  0.0  0.1  14188  9472 ?        Ss   20:31   0:00 sshd: swebot [priv]
jules        929  0.0  0.0  14448  6048 ?        S    20:31   0:00 sshd: swebot@notty
root       47852  0.0  0.1  14220  9472 ?        Ss   20:48   0:00 sshd: swebot [priv]
jules      47863  0.0  0.0  14480  6168 ?        S    20:48   0:00 sshd: swebot@notty
```

### Analysis
* The host hypervisor orchestrator accesses the guest via the VSOCK SSH tunnel as user `swebot`.
* The sessions run headless with no TTY allocation (`@notty`).
* Swebot coordinates the tmux session `default` and monitors `/run/devbox-session/default/` tmpfs FIFO files via `inotifywait`.

---

## 5. Systemd Volatile State Isolation

```bash
$ cat /etc/systemd/system/var-lib-systemd.mount
[Unit]
Description=Mount tmpfs on /var/lib/systemd
DefaultDependencies=no
Conflicts=umount.target
Before=local-fs.target umount.target

[Mount]
What=tmpfs
Where=/var/lib/systemd
Type=tmpfs
Options=rw,nosuid,nodev,size=4075060k,nr_inodes=10240
```

### Analysis
* Systemd state (journald, machine-id, random seed) is mounted into a dedicated 4 GiB volatile `tmpfs` at `/var/lib/systemd`.
* Keeps ephemeral runtime state off the `/dev/vdb` overlayfs to eliminate unnecessary disk write amplification.
