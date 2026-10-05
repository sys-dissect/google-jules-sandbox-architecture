# Virtio Virtual Hardware & Storage Subsystem Deep Dive

## 1. Virtio Device Register Mapping

Inspection of `/sys/bus/virtio/devices/` and `/proc/interrupts` reveals the hardware-to-virtual-bus mapping of the Firecracker microVM:

| Virtio Device | Subsystem Type | Virtio ID | Hardware Resource | Assigned IRQ | IO-APIC Binding | SMP CPU Affinity |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `virtio0` | Virtio-Block | `0x0002` | `/dev/vda` (4.36 GiB SquashFS base image) | IRQ 5 | `IO-APIC 5-edge` | CPU 1 |
| `virtio1` | Virtio-Block | `0x0002` | `/dev/vdb` (100 GiB ext4 writable overlay) | IRQ 6 | `IO-APIC 6-edge` | CPU 2 |
| `virtio2` | Virtio-Net | `0x0001` | `eth0` (`06:00:c0:a8:00:02`, MTU 1500) | IRQ 7 | `IO-APIC 7-edge` | CPU 3 |
| `virtio3` | Virtio-VSOCK | `0x0013` (19) | Guest CID 123 (VMM notify on Host CID 2) | IRQ 8 | `IO-APIC 8-edge` | CPU 1 |
| `ttyS0` | Serial Console | N/A | Standard 8250 UART serial port | IRQ 4 | `IO-APIC 4-edge` | CPU 2 |
| `ACPI:Ged` | ACPI Event | N/A | Generic Event Device (microVM lifecycle) | IRQ 9 | `IO-APIC 9-edge` | CPU 0 |

```bash
$ for dev in /sys/bus/virtio/devices/*; do
    echo "$dev: device=$(cat $dev/device) vendor=$(cat $dev/vendor) features=$(cat $dev/features)"
  done
/sys/bus/virtio/devices/virtio0: device=0x0002 vendor=0x0000 features=0000010000000000000000000000010010000000000000000000000000000000
/sys/bus/virtio/devices/virtio1: device=0x0002 vendor=0x0000 features=0000000000000000000000000000010010000000000000000000000000000000
/sys/bus/virtio/devices/virtio2: device=0x0001 vendor=0x0000 features=1100010110111011000000000000010010000000000000000000000000000000
/sys/bus/virtio/devices/virtio3: device=0x0013 vendor=0x0000 features=0000000000000000000000000000000010000000000000000000000000000000
```

---

## 2. Microarchitecture Cache & Clocksource

* **Clocksource:**
  * Available: `tsc`, `kvm-clock`
  * Active: `tsc` (direct invariant TSC clock with zero hypercall overhead)
* **CPU Cache Topology (Intel Xeon @ 2.30GHz):**
  * L1 Data: 32 KiB (per core)
  * L1 Instruction: 32 KiB (per core)
  * L2 Unified: 256 KiB (per core)
  * L3 Unified: 45 MiB (`46080K`, shared across vCPUs from physical host socket)

---

## 3. Golden Image Superblock Dissection (`/dev/vda`)

Direct binary parsing of the first 96 bytes of the SquashFS filesystem on `/dev/vda`:

```python
# Superblock header decoding:
# Magic: 0x73717368 ("sqsh")
# Inode count: 330,916
# Block size: 131,072 bytes (128 KiB)
# Compression algorithm: xz (LZMA2)
# Creation timestamp: 1970-01-01T00:00:00Z (deterministic reproducible build)
# SquashFS specification version: 4.0
```

### Analysis
* **High-Density Golden Image:** 330,916 files comprising the entire pre-baked developer ecosystem (Ubuntu 24.04, Python 3.12, Node 22, Go 1.24, Rust 1.94, Google Chrome 268 MB, Android SDK) are compressed into just 4.36 GiB using `xz` 128 KiB blocks.
* **Deterministic Build Timestamp:** The superblock creation time is clamped to Unix epoch `0` (`1970-01-01T00:00:00Z`), confirming hermetic, reproducible golden image builds inside Google's release pipeline.
