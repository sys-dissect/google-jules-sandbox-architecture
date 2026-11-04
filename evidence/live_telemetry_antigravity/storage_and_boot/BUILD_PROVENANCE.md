# Base Image Build Provenance & Golden Snapshot Timeline

Forensic audit of build logs preserved in the read-only golden image (`/rom/var/log/`) reconstructs the exact build pipeline Google used to create the Jules devbox base image.

---

## 1. Golden Image Build Timeline

```text
2026-02-10 14:05 UTC   Base OS Bootstrap (debootstrap noble from ftpmaster.internal)
        │
2026-02-20 20:38 UTC   Kernel Compiled (feyu@feyu-encarta.c.googlers.com with GCC 15.2)
        │
2026-03-02 16:40 UTC   Core Toolchain Baked (Python 3.12, Node 22, Go, Rust, Android, Chrome 145)
        │
2026-03-06 16:39 UTC   Final Package Updates (libnss3 security upgrade)
        │
2026-03-06 17:10 UTC   SquashFS 4.0 Compressed & Ext4 Scratch Partition Created (tune2fs)
```

---

## 2. Base OS Bootstrap (`/rom/var/log/bootstrap.log`)
* **Build Tool:** `debootstrap` targeting Ubuntu 24.04 (`noble`).
* **Google Internal Mirror:** `http://ftpmaster.internal/ubuntu/dists/noble/InRelease`
* **Build Root Directory:** `/build/chroot/`
* **Initial Packages:** `base-files`, `base-passwd`, `bash`, `coreutils`, `dpkg`, `e2fsprogs`.

---

## 3. SquashFS 4.0 Superblock Header
Parsing the first 96 bytes of `/dev/vda`:

| Offset | Field | Value | Interpretation |
| :--- | :--- | :--- | :--- |
| `0x00` | `s_magic` | `0x73717368` | SquashFS magic signature (`sqsh`) |
| `0x04` | `inodes` | `330,916` | Total filesystem inodes |
| `0x08` | `mkfs_time` | `0` | Unix epoch `0` (`1970-01-01T00:00:00Z`) for hermetic reproducibility |
| `0x0C` | `block_size` | `131,072` | 128 KiB compression block size |
| `0x10` | `fragments` | `15,591` | Tail fragments count |
| `0x14` | `compression` | `4` | `XZ` (LZMA2) compression algorithm |
| `0x18` | `block_log` | `17` | $2^{17} = 131,072$ |
| `0x1A` | `flags` | `0x0060` | Superblock flags |
| `0x1C` | `no_ids` | `14` | Number of UID/GID mappings |
| `0x1E` | `s_major` / `s_minor` | `4.0` | SquashFS specification version 4.0 |
