# Cross-Task Durability & State Isolation Audit

Investigation into cross-task state preservation vs. isolation boundaries across independent Jules task invocations.

---

## 1. Experimental Summary

| Parameter | Task Run 1 | Task Run 2 (Subsequent Task) |
| :--- | :--- | :--- |
| **Task ID** | `14165408129265143467` | `10448450951705239643` |
| **Boot Time** | `2026-10-05 07:16:43` | `2026-10-05 08:32:26` |
| **`/tmp/marker.txt`** | Created (`Mon Oct 5 07:16:43 UTC 2026`) | **Not found** |
| **`/home/jules/marker.txt`** | Created (`Mon Oct 5 07:16:43 UTC 2026`) | **Not found** |
| **`/app/marker.txt`** | Committed to git | Present via git clone |
| **Isolation Verdict** | Base environment | Clean isolated microVM snapshot |

---

## 2. Forensic Analysis of Filesystem Superblock

To establish how fresh instances are provisioned, `tune2fs` inspection was conducted on `/dev/vdb` (the writable overlay scratch disk):

```bash
$ sudo tune2fs -l /dev/vdb
Filesystem volume name:   <none>
Last mounted on:          /rom/overlay
Filesystem UUID:          bf3534b4-d500-47bf-85f0-619213bc540f
Filesystem magic number:  0xEF53
Filesystem state:         clean
Errors behavior:          Continue
Filesystem OS type:       Linux
Inode count:              6553600
Block count:              26214400
Reserved block count:     1310720
Free blocks:              25565576
Free inodes:              6551805
First block:              0
Block size:               4096
Fragment size:            4096
Blocks per group:         32768
Fragments per group:      32768
Inodes per group:         8192
Inode blocks per group:   512
Filesystem created:       Fri Mar  6 17:10:25 2026
Last mount time:          Wed Nov  4 10:44:26 2026
Last write time:          Wed Nov  4 10:44:26 2026
Mount count:              1
Maximum mount count:      -1
Last checked:             Fri Mar  6 17:10:25 2026
Check interval:           0 (<none>)
```

### Key Architectural Findings:
1. **Snapshots vs Formatting**: `Filesystem created: Fri Mar 6 17:10:25 2026`. The scratch disk is not created dynamically at runtime (`mkfs.ext4` is never called during VM boot). The orchestrator attaches a copy-on-write clone of an existing ext4 disk image.
2. **Durability Boundary**:
   * Intra-task: Mutations write directly to `/dev/vdb` and remain durable across turns.
   * Cross-task: The orchestrator discards the copy-on-write scratch disk layer and provisions a fresh snapshot of the golden ext4 template, guaranteeing pristine isolation between distinct customer tasks.
