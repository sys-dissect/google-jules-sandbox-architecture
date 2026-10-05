# Security Confinement, LSM, and Cgroups v2 Resource Allocation

## 1. Linux Security Modules (LSM) & Confinement

```bash
$ cat /sys/kernel/security/lsm
No LSM
$ sudo aa-status
No AppArmor status
$ sudo sestatus
No SELinux
```

### Analysis
* **Zero Mandatory Access Control (MAC):** Neither AppArmor nor SELinux is active in the custom guest kernel (`Linux 6.8.0 #1 SMP PREEMPT_DYNAMIC`).
* **Privilege Model:**
  * User: `jules` (UID 1001, GID 1001).
  * Sudo Permissions (`sudo -l`):
    ```text
    User jules may run the following commands on devbox:
        (ALL : ALL) ALL
        (ALL) NOPASSWD: ALL
    ```
  * User `jules` possesses complete passwordless `sudo` rights without restriction.
* **Architectural Rationale:** Confinement in Jules is enforced strictly at the **hardware virtual machine boundary** (KVM + Firecracker + static MMIO registers + private bridge network), rendering in-guest kernel MAC layers redundant and allowing developer toolchains full root access without permission errors.

---

## 2. Cgroups v2 Resource Limits

```bash
$ cat /sys/fs/cgroup/cgroup.controllers
cpuset cpu io memory hugetlb pids

$ cat /sys/fs/cgroup/cgroup.subtree_control
cpuset cpu io memory pids

$ cat /sys/fs/cgroup/user.slice/memory.max
max

$ cat /sys/fs/cgroup/user.slice/cpu.max
max 100000

$ cat /sys/fs/cgroup/user.slice/pids.max
max
```

### Analysis
* **Unthrottled User Slice:**
  * `memory.max = max`: Workloads are not constrained by artificial cgroup memory ceilings; they can utilize the entire 8 GiB physical RAM allocation.
  * `cpu.max = max 100000`: No CPU quota limits are applied; processes can saturate all 4 vCPUs continuously without CFS bandwidth throttling.
  * `pids.max = max`: No arbitrary fork caps are placed on task creation.
* **Contrast with Process Sandboxes:** Unlike container or gVisor environments that enforce strict cgroup quotas, Jules allocates native, unthrottled hardware resources within the microVM envelope.
