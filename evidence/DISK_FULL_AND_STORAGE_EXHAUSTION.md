# EMPIRICAL AUDIT: EXT4 SCRATCH DISK EXHAUSTION, OVERLAYFS CREDENTIAL BYPASS, AND DISK-FULL RESILIENCE

**Classification:** Tier 1 (Directly Observed via Live Out-of-Band Tailcat SSH Probes)  
**Date:** 2026-11-04  
**Target:** Live Google Jules Devbox MicroVM  
**Reference Kernel:** `Linux devbox 6.8.0 #1 SMP PREEMPT_DYNAMIC`  
**Storage Architecture:** Virtio-MMIO Block Device `virtio1` (`/dev/vdb` ext4) backing OverlayFS Upperdir (`/overlay/root`)

---

## Executive Summary

To assess hypervisor boundary stability, file system error handling, and orchestration resilience under resource exhaustion, we conducted a controlled multi-stage disk saturation probe on the live Google Jules devbox microVM.

By driving the writable scratch partition (`/dev/vdb`, 100 GiB ext4) to absolute physical saturation (0 free blocks available), we uncovered two critical systems insights into how Google's sandbox manages storage limits:

1. **The OverlayFS Root Credential Bypass (`override_creds`)**:  
   Ext4 defaults to a 5.0% root reservation (`1,310,720` blocks, ~5.02 GiB) intended to allow administrative recovery when non-root users exhaust storage. While writes directly to the underlying ext4 partition (`/rom/overlay`) strictly enforce this reservation (returning `ENOSPC` to user `jules`), writes traversing the OverlayFS root (`/`) **completely bypass the 5% root reservation**. Because OverlayFS was mounted by root during early boot (`/usr/sbin/overlay-init`), the Linux kernel's `ovl_write_iter()` calls `override_creds(&init_cred)`, executing backing ext4 block allocations under `UID 0`. Consequently, an unprivileged user process (`jules`, UID 1001) is capable of writing an extra 5,169 MB into the reserved pool, driving the disk to complete physical block exhaustion.
2. **Tmpfs Decoupling & Control Plane Fault Isolation**:  
   Despite absolute 100% saturation on `/dev/vdb` (where all subsequent `write(2)` and `fallocate(2)` calls fail with `errno 28 ENOSPC`), the microVM remains completely stable. Memory-backed tmpfs mounts—specifically `/run` (1.6 GiB) housing the `/run/devbox-session/default/` host FIFO harness, and `/var/lib/systemd` (3.9 GiB) housing journald—remain fully writable and operational. The Firecracker hypervisor does not pause the microVM, the Linux kernel does not panic or remount ext4 read-only, and out-of-band Tailcat WireGuard SSH connectivity is fully preserved.

---

## 1. Scratch Partition Geometry & Baseline Allocation

Forensic inspection via `tune2fs -l /dev/vdb` and Python `os.statvfs('/')` establishes the baseline storage configuration:

```text
Filesystem volume name:   overlay
Last mounted on:          /
Filesystem UUID:          a9893320-d2ab-4aca-98ea-9a5954d46d7d
Filesystem magic number:  0xEF53
Block size:               4096 bytes
Block count:              26,214,400 (100.00 GiB / 107.37 GB)
Reserved block count:     1,310,720 (5.00% = 5.016 GiB)
Reserved blocks uid:      0 (user root)
Reserved blocks gid:      0 (group root)
Errors behavior:          Continue
Filesystem state:         clean
```

### Baseline `statvfs` Telemetry

```python
import os

s = os.statvfs("/home/jules")
bs = s.f_frsize  # 4096 bytes

print(f"Total blocks:      {s.f_blocks} ({s.f_blocks * bs / (1024**3):.3f} GiB)")
print(f"Free blocks:       {s.f_bfree} ({s.f_bfree * bs / (1024**3):.3f} GiB)")
print(f"Available to user: {s.f_bavail} ({s.f_bavail * bs / (1024**3):.3f} GiB)")
print(
    f"Reserved buffer:   {s.f_bfree - s.f_bavail} ({(s.f_bfree - s.f_bavail) * bs / (1024**3):.3f} GiB)"
)
print(f"Free Inodes:       {s.f_ffree} (out of {s.f_files})")
```

**Measured Baseline Values:**
* **Total Usable Capacity (`f_blocks`)**: 25,656,558 blocks (97.872 GiB)
* **Free Blocks (`f_bfree`)**: 25,263,788 blocks (96.374 GiB)
* **Available to User `jules` (`f_bavail`)**: 23,948,972 blocks (91.358 GiB)
* **Root Reserved Buffer (`f_bfree - f_bavail`)**: 1,314,816 blocks (5.016 GiB)
* **Free Inodes (`f_ffree`)**: 6,519,905 inodes (out of 6,553,600)

---

## 2. Empirical Discovery: OverlayFS Root Credential Bypass

In standard Linux ext4 deployments, when disk consumption reaches the point where `f_bavail == 0`, non-root users are locked out from allocating further disk blocks. This 5% buffer guarantees that daemons logging to `/var/log` or administrative users invoking recovery tools retain enough space to troubleshoot.

To verify whether this boundary holds inside Google Jules, we tested block allocation directly against the raw ext4 mount point (`/rom/overlay`) versus the OverlayFS unified mount point (`/`):

### The Comparative Experiment

We saturated user-available space (`91.36 GiB`), bringing `f_bavail` to `0.00 GiB` while leaving `4.37 GiB` in `f_bfree` (the reserved buffer). Then, unprivileged user `jules` (UID 1001, GID 1001, `CapEff = 0`) attempted synchronous writes to both filesystems:

```python
# Saturated state: Free = 4.37 GiB, Avail = 0.00 GiB

# Test 1: Direct ext4 write (bypassing OverlayFS)
with open("/rom/overlay/direct_test/write_jules.txt", "w") as f:
  f.write("direct ext4 payload\n")
  f.flush()
  os.fsync(f.fileno())

# Test 2: OverlayFS write
with open("/home/jules/write_jules_ovl.txt", "w") as f:
  f.write("overlayfs payload\n")
  f.flush()
  os.fsync(f.fileno())
```

### Empirical Results

```text
=== PREPARING SPACE CONSUMPTION ===
Direct ext4 (/rom/overlay): Free=4.37G, Avail=0.00G
OverlayFS (/home/jules):    Free=4.37G, Avail=0.00G

=== TEST 1: Direct ext4 write as user jules ===
Direct ext4 write as jules: FAILED: errno=28 (ENOSPC: No space left on device)

=== TEST 2: OverlayFS write as user jules ===
OverlayFS write as jules: SUCCEEDED
```

### Kernel Root Cause Analysis

Why did `Test 1` fail while `Test 2` succeeded under the exact same unprivileged user UID 1001?

1. **Direct Ext4 Path (`fs/ext4/balloc.c`)**:  
   When the write hits `ext4_has_free_clusters()`, the kernel checks the effective credentials of the calling process:
   ```c
   if (free_clusters >= root_clusters)
       return 1;
   if (uid_eq(current_fsuid(), sbi->s_resuid) ||
       gid_eq(current_fsgid(), sbi->s_resgid) ||
       capable(CAP_SYS_RESOURCE))
       return 1;
   return 0; // REJECT with ENOSPC
   ```
   Because `current_fsuid()` is `1001` (user `jules`) and `CAP_SYS_RESOURCE` is not in `CapEff`, ext4 immediately rejects the write with `ENOSPC`.

2. **OverlayFS Path (`fs/overlayfs/file.c`)**:  
   When the write is routed through OverlayFS, the VFS driver calls `ovl_write_iter()`. To ensure OverlayFS can create and manipulate upperdir files and whiteouts regardless of the caller's restricted umask or credentials, OverlayFS invokes:
   ```c
   revert_creds = override_creds(ovl_creds(file_inode(file)->i_sb));
   ```
   Because `/usr/sbin/overlay-init` mounted OverlayFS as `root` (UID 0), `ovl_creds` holds the credentials of `root`. When `ovl_write_iter()` calls the underlying ext4 file write function (`vfs_iter_write`), `current_fsuid()` evaluates to **`0` (`root`)**!  
   Ext4 satisfies `uid_eq(current_fsuid(), sbi->s_resuid)` and allocates the block from the reserved pool.

**Architectural Consequence:**  
In the Google Jules sandbox, the 5% root reservation on `/dev/vdb` is completely ineffective against unprivileged agent processes. Any workload running as `jules` can deplete 100% of the underlying physical storage blocks.

---

## 3. Failure Modes at 100% Absolute Saturation

We continued writing sequential 1 MB data blocks as user `jules` through OverlayFS until the physical disk could accept no further blocks:

```text
Free: 96.37G, Avail: 91.36G
Allocating 91.31G via posix_fallocate...
After base: Free: 5.06G, Avail: 49.99MB

Writing sequential 1MB blocks as user jules...
Write failed after 5,169 MB: errno=28 (ENOSPC: No space left on device)

At failure: Free: 0.02G, Avail: 0.00MB
Root write returncode: 1 (errno=28 ENOSPC)
```

### Observed Error Codes Across System Interfaces

| Operation | Context / User | Syscall / Interface | Return Code / Error | Kernel / Shell Message |
| :--- | :--- | :--- | :--- | :--- |
| Pre-allocation | `jules` (UID 1001) | `fallocate(fd, 0, 97G)` | `errno 28` | `posix_fallocate failed: ENOSPC (No space left on device)` |
| Stream Write | `jules` (UID 1001) | `write(fd, buf, 1MB)` | `errno 28` | `Write failed after 5169 MB: ENOSPC (No space left on device)` |
| File Creation | `jules` (UID 1001) | `open(..., O_CREAT)` | `errno 28` | `User write FAILED as expected: errno=28 (ENOSPC)` |
| Root Allocation | `root` (UID 0) | `fallocate(fd, 0, 16MB)` | `errno 28` | `Root fallocate FAILED: errno=28 (ENOSPC: No space left on device)` |
| Shell Append | `root` (UID 0) | `sh -c 'echo test > file'` | Exit code `1` | `sh: 1: echo: echo: I/O error` (VFS buffer writeback drop) |

### The `0.02 GiB` Physical Floor
At absolute saturation, `statvfs` reported `Free = 0.02 GiB` (approx. 4,096 blocks = 16.7 MB). This floor represents ext4 metadata journal reservations (`has_journal`) and reserved GDT blocks (`Reserved GDT blocks: 1024`) which the ext4 block allocator strictly protects from data extents to prevent filesystem structure corruption.

---

## 4. Hypervisor & Kernel Boundary Behavior

A critical vulnerability in hypervisor storage management is hypervisor pause: in some cloud virtualization environments (such as VMware ESXi or QEMU with `werror=stop`), guest disk exhaustion causes the hypervisor to pause vCPU execution entirely.

We audited `dmesg` immediately following 100% saturation:

```text
# dmesg | tail -20
[20973901.811610] docker0: port 1(veth741ef1c) entered forwarding state
[20973901.933949] docker0: port 1(veth741ef1c) entered disabled state
[20973901.934010] veth396cc43: renamed from eth0
[20973902.022466] docker0: port 1(veth741ef1c) entered disabled state
[20973902.023852] veth741ef1c (unregistering): left allmulticast mode
[20973902.023856] veth741ef1c (unregistering): left promiscuous mode
[20973902.023858] docker0: port 1(veth741ef1c) entered disabled state
[20977626.705380] random: crng reseeded due to virtual machine fork
```

### Kernel Stability Findings

1. **Zero Kernel Panics**: The custom Linux 6.8 kernel handled `ENOSPC` cleanly at the VFS layer.
2. **No Read-Only Remounts**: Unlike storage medium hardware faults, `errors=continue` configured on `/dev/vdb` remained in effect; ext4 remained mounted read-write (`rw,relatime`).
3. **No Hypervisor Pause**: AWS Firecracker Virtio-MMIO block emulation (`virtio-block`) implements standard asynchronous request completion; block writes exceeding capacity return `VIRTIO_BLK_S_IOERR` without freezing host vCPUs.
4. **No CRNG Reseed Anomalies**: No VM snapshot pause or fork events were triggered by disk exhaustion.

---

## 5. Tmpfs Decoupling & Control Plane Protection

Why does the microVM remain responsive over SSH and able to execute host orchestrator commands even when `/dev/vdb` is completely full?

Examination of `/proc/mounts` reveals deliberate memory-backed mount isolation:

```text
tmpfs /run tmpfs rw,nosuid,nodev,noexec,relatime,size=1632764k,mode=755 0 0
tmpfs /var/lib/systemd tmpfs rw,relatime,size=4081912k 0 0
```

### Empirical Tmpfs Test Under 100% Scratch Saturation

While `/dev/vdb` was at 100% saturation (rejecting all disk writes), we executed synchronous read/write/fsync tests against the tmpfs mounts:

```python
# Synchronous write/read against host orchestrator harness directory
path = "/run/devbox-session/default/tmpfs_test.txt"
with open(path, "w") as f:
  f.write("tmpfs is unaffected by ext4 saturation\n")
  f.flush()
  os.fsync(f.fileno())

with open(path, "r") as f:
  content = f.read().strip()
os.remove(path)

print(f"Tmpfs Result: {content}")
```

**Output:**
```text
Tmpfs /run/devbox-session/default/tmpfs_test.txt: WRITE & READ SUCCEEDED -> "tmpfs is unaffected by ext4 saturation"
```

### Architectural Protection Matrix

| Subsystem | Mount Path | Backing Store | State Under 100% `/dev/vdb` Exhaustion |
| :--- | :--- | :--- | :--- |
| **Command Execution Harness** | `/run/devbox-session/default/` | `tmpfs` (1.6 GiB RAM) | **Operational**. FIFOs (`stdin`, `stdout`, `command`, `stamp`) continue passing commands and status between host orchestrator and guest tmux. |
| **System Journald Logging** | `/var/lib/systemd/` | `tmpfs` (3.9 GiB RAM) | **Operational**. `systemd-journald` continues logging runtime events without disk I/O blocking or journal corruption. |
| **Host Network Ingress** | `/dev/pts/`, `/run/sshd/` | Memory / Devpts | **Operational**. VSOCK SSH (`socat` bridge on port 22) and Tailcat WireGuard netstack run entirely in user-space RAM. |
| **Toolchains & Base System** | `/rom` | SquashFS 4.0 (`/dev/vda`) | **Read-Only Immutable**. Core binaries (`bash`, `git`, `python3`, `node`) never depend on scratch space for execution. |
| **User Scratch & Git Clones** | `/home/jules`, `/app`, `/tmp` | Ext4 upperdir (`/dev/vdb`) | **Write-Blocked (`ENOSPC`)**. Existing files readable; modifications or new allocations rejected with `errno 28`. |

---

## 6. Fast Recovery & Cleanup Semantics

Ext4 storage recovery is instantaneous upon file unlinking:

```python
# Unlink test files
os.remove("/home/jules/test_baseline.img")
os.remove("/home/jules/test_stream.img")
```

Immediately following the `unlink(2)` syscall:
* `f_bfree` returned from `0.02 GiB` to **`96.37 GiB`** (25,263,788 blocks).
* `f_bavail` returned from `0.00 GiB` to **`91.36 GiB`** (23,948,972 blocks).
* Ext4 block bitmaps and inode structures updated synchronously without requiring `e2fsck`, remounting, or guest rebooting.

---

## 7. Comparative Architectural Takeaways

| Dimension | Standard Linux Box (Direct Ext4) | Google Jules MicroVM (SquashFS + Ext4 Overlay) | Gemini Spark (gVisor) |
| :--- | :--- | :--- | :--- |
| **Root 5% Reservation** | Enforced against non-root UIDs | **Bypassed** via OverlayFS `override_creds(&init_cred)` | Virtualized memory buffer / sandbox quota |
| **Host Control Plane Impact** | High (if `/run` or `/var/log` fills, daemons freeze) | **Zero** (`/run` and `/var/lib/systemd` isolated in tmpfs) | Zero (IPC mediated by host RPCs) |
| **Hypervisor Reaction** | N/A | Firecracker returns `VIRTIO_BLK_S_IOERR`; vCPUs continue running | Sandbox returns `ENOSPC` via Sentry |
| **Base OS Integrity** | Vulnerable to scratch corruption | **100% Immutable** (`/dev/vda` SquashFS 4.0 read-only) | 100% Immutable (gVisor read-only layers) |
