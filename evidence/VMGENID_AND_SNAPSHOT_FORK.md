# VM Generation ID & Firecracker Snapshot-Fork Detection

Mechanistic explanation for the warm-resume behaviour observed throughout this study
(journal boot-ID persistence, `crng reseeded due to virtual machine fork`, TSC/clock
resync). Captured **2026-11-07** from the live devbox.

Raw: [`raw/guest_host_comms_20261107T102856Z/system/vmgenid.txt`](raw/guest_host_comms_20261107T102856Z/system/vmgenid.txt).

---

## 1. The device is exposed via ACPI

```text
/sys/bus/acpi/devices/FCVMGID:00
  uevent:    DRIVER=vmgenid
             MODALIAS=acpi:FCVMGID:VM_GEN_COUNTER:
  path:      \_SB_.VGEN
  modalias:  acpi:FCVMGID:VM_GEN_COUNTER:
  driver ->  /sys/bus/acpi/drivers/vmgenid
```

The disassembled DSDT (same bytes as the published evidence) contains:

```text
\._SB_VGEN
._SB_VGEN
_HID  FCVMGID
_CID  VM_Gen_Counter
_DDN  VM_Gen_Counter
```

So the ACPI object at `\_SB.VGEN` advertises HID `FCVMGID` with compatible ID
`VM_Gen_Counter`; Linux binds the **`vmgenid`** driver to it.

```text
$ zcat /proc/config.gz | grep VMGENID
CONFIG_VMGENID=y
```

It shares the ACPI GED interrupt (`IRQ 9-edge ACPI:Ged`) with other Firecracker
event devices.

## 2. Each snapshot fork reseeds the kernel CRNG

```text
[    0.777127] random: crng init done
[21225104.888382] random: crng reseeded due to virtual machine fork
[21225960.027544] random: crng reseeded due to virtual machine fork
[21228123.970586] random: crng reseeded due to virtual machine fork
[21229712.931897] random: crng reseeded due to virtual machine fork
[21230839.163730] random: crng reseeded due to virtual machine fork
```

The `vmgenid` driver watches the generation counter; when Firecracker restores a
snapshot (a "fork"), the counter changes, the driver raises the VM-generation event,
and the kernel reseeds its CRNG. This is exactly why distinct task sessions can share
the same `boot_id` and journal while still getting independent randomness.

## 3. Why this matters for the lifecycle model

These independently observed facts are all one mechanism:

| Observation | Explanation |
| :--- | :--- |
| `boot_id` identical across sessions (and to the published evidence) | VM is resumed, not cold-booted; the kernel state (including boot ID) is restored |
| `journalctl --list-boots` spans 2026-03-06 → 2026-11-07 under one boot ID | same continuous kernel lineage, resumed repeatedly |
| `/proc/uptime` is minutes while dmesg monotonic is ~245.7 days | boottime/monotonic adjusted on resume; printk timestamps retain elapsed wall time |
| `random: crng reseeded due to virtual machine fork` (×5) | `vmgenid` detected each fork and reseeded the CRNG |
| guest wall clock within ~1 s of host HTTP `Date` | clock resynchronised at resume |

So the "fresh microVM" observed per task is a **warm snapshot resume**, not a new
boot; cross-task isolation is enforced by discarding/recloning the scratch layer,
not by rebooting the kernel. This corroborates
[`PERSISTENCE.md`](PERSISTENCE.md), [`CROSS_TASK_CHECK.md`](CROSS_TASK_CHECK.md),
and [`SNAPSHOT_AND_PROXY_DEEPDIVE.md`](SNAPSHOT_AND_PROXY_DEEPDIVE.md) with a
concrete in-guest device-level proof.

## 4. Reproduction

```bash
find /sys -iname '*vmgen*'
cat /sys/bus/acpi/devices/FCVMGID:00/{uevent,path,modalias}
zcat /proc/config.gz | grep -i vmgenid
sudo dmesg | grep -iE 'crng reseeded|virtual machine fork'
strings /sys/firmware/acpi/tables/DSDT | grep -iE 'VGEN|VM_Gen_Counter|FCVMGID'
```

---

## 5. Related: cloud metadata is reachable in DNS but not on the wire

```text
$ getent hosts metadata.goog
169.254.169.254  metadata.goog

$ ip route get 169.254.169.254
169.254.169.254 via 192.168.0.1 dev eth0 src 192.168.0.2 uid 1001

$ curl -m4 -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/
curl: (7) Failed to connect ... port 80: Couldn't connect to server
```

The host `dnsmasq` resolves `metadata.goog` to the link-local metadata address, but
the gateway drops the connection (no explicit `iptables` rule; the Firecracker
network simply does not route it). AWS IMDSv1/v2 and the IPv6 GCP address
(`[fd20:ce::254]`) are likewise unreachable.

The swebot SSH sessions also carry an **empty environment** (`/proc/<pid>/environ`),
confirming that the orchestrator drives the guest purely through commands/files, not
through injected environment variables.
