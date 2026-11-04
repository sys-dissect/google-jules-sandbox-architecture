# EMPIRICAL AUDIT: KERNEL SECURITY CONFIG, EBPF, AND VCPU TOPOLOGY

**Classification:** Tier 1 (Directly Observed via Live Out-of-Band Tailcat SSH Probes)  
**Date:** 2026-11-04  
**Target:** Live Google Jules Devbox MicroVM  
**Reference Kernel:** `Linux devbox 6.8.0 #1 SMP PREEMPT_DYNAMIC` (compiled by `feyu@feyu-encarta.c.googlers.com`)  
**Hypervisor Engine:** AWS Firecracker (ACPI: `FIRECK` / `FCAT 20240119`)

---

## Executive Summary

Prior audits confirmed that Google Jules runs in a dedicated KVM microVM using AWS Firecracker with Virtio-MMIO and SquashFS/ext4 dual-disk overlay. However, the exact guest kernel build configuration, eBPF programmability, scheduling topology, and cgroups v2 boundary quotas remained uninspected.

Through live empirical probing of `/proc/config.gz`, `/sys/fs/cgroup/`, `/sys/devices/system/cpu/`, `/sys/kernel/mm/`, and direct system call invocation via Python `ctypes`, we uncovered three major systems architectural findings:

1. **Complete Omission of Kernel Seccomp (`# CONFIG_SECCOMP is not set`)**:  
   Unlike Docker, Kubernetes, or gVisor sandboxes where seccomp syscall filtering is the primary barrier, the Jules guest kernel was compiled **without seccomp support entirely**. Guest processes have unrestricted access to all 450+ Linux x86_64 system calls.
2. **Strictly Monolithic Kernel Architecture (`# CONFIG_MODULES is not set`)**:  
   Loadable kernel modules (LKMs) are completely disabled. `/proc/modules` is empty and `lsmod` exits cleanly with zero output. Root cannot insert custom kernel modules or drivers, eliminating kernel-space rootkit persistence within the VM.
3. **Completely Unthrottled Guest Cgroups v2 Hierarchy**:  
   Both `user.slice` (the agent's interactive environment) and `system.slice` (systemd and daemons) are configured with `memory.max = max` and `cpu.max = max 100000`. Google delegates 100% of resource quotas, burst limits, and isolation enforcement to the host Firecracker cgroup boundary.

---

## 1. Kernel Security Hardening & Confinement Profile

Forensic extraction from `/proc/config.gz` and runtime sysfs inspection confirms the precise kernel hardening flags chosen by Google's kernel builder:

```text
[Monolithic Architecture]
# CONFIG_MODULES is not set       <-- Zero loadable module support; purely monolithic vmlinux
# CONFIG_WATCHDOG is not set      <-- Watchdog timer hardware omitted

[Syscall Filter & Isolation]
# CONFIG_SECCOMP is not set       <-- Seccomp filter completely compiled out of guest kernel
# CONFIG_SECURITY is not set      <-- Linux Security Modules (LSM) framework disabled
# CONFIG_SECURITYFS is not set    <-- /sys/kernel/security is unmounted
# CONFIG_AUDIT is not set         <-- Kernel auditing disabled
CONFIG_AUDIT_ARCH=y

[Address Space Layout & Memory Protections]
# CONFIG_RANDOMIZE_BASE is not set <-- Kernel ASLR (KASLR) disabled at compile-time
CONFIG_RANDOMIZE_KSTACK_OFFSET=y   <-- Per-syscall kernel stack offset randomization enabled
CONFIG_STACKPROTECTOR=y            <-- Stack canaries enabled
CONFIG_STACKPROTECTOR_STRONG=y     <-- Aggressive stack canary protection
CONFIG_FORTIFY_SOURCE=y            <-- Kernel string buffer bounds checks
CONFIG_STRICT_KERNEL_RWX=y         <-- Kernel code pages mapped strictly Read-Only / Executable
CONFIG_STRICT_DEVMEM=y             <-- /dev/mem access restricted to prevent raw RAM scraping
# CONFIG_HARDENED_USERCOPY is not set

[Runtime Sysctl Hardening]
/proc/sys/kernel/randomize_va_space = 2  (Full user-space ASLR active)
/proc/sys/kernel/kptr_restrict = 1       (Kernel pointer addresses concealed from non-root)
/proc/sys/kernel/dmesg_restrict = 0      (Kernel log ring buffer readable by non-root)
/proc/sys/kernel/perf_event_paranoid = 2 (Unprivileged hardware perf tracing blocked)
```

### Architectural Analysis: Why Disable Seccomp and KASLR?
- **Disabling Seccomp**: Coding agents execute arbitrary developer-authored code, package installation scripts (`apt-get`, `cargo`, `pip`), compiler toolchains, debuggers (`gdb`, `ptrace`), and emulation engines. Imposing seccomp inside the guest creates brittle edge cases and syscall friction. Because the microVM is bounded by the KVM hardware hypervisor barrier, Google opted for zero in-guest syscall restrictions.
- **Disabling KASLR**: Firecracker microVMs are optimized for sub-10ms warm boots and snapshot restorations. Disabling `CONFIG_RANDOMIZE_BASE` allows deterministic physical memory mapping, eliminating page-table relocation overhead during warm resume.

---

## 2. eBPF & Tracing Capabilities

We verified whether the devbox allows agent processes or debugging tools to attach eBPF programs:

```bash
# Sysctl inspection
cat /proc/sys/kernel/unprivileged_bpf_disabled
# Output: 2

# Direct bpf(2) system call probe via ctypes
python3 -c 'import ctypes, ctypes.util; libc=ctypes.CDLL(ctypes.util.find_library("c")); print("ret:", libc.syscall(321, 0, 0, 0))'
# Output: ret: -1
```

* **`unprivileged_bpf_disabled = 2`**: Once set to `2`, unprivileged users cannot invoke the `bpf(2)` syscall under any circumstances. This setting is immutable until reboot.
* **Kernel Compilation**: `CONFIG_BPF=y`, `CONFIG_BPF_SYSCALL=y`, and `CONFIG_BPF_UNPRIV_DEFAULT_OFF=y` are set, but `# CONFIG_FTRACE is not set` and `# CONFIG_BPF_PRELOAD is not set`.
* **Tooling**: `bpftool` is not installed.
* **Security Implication**: The agent cannot load unprivileged eBPF probes. Privileged (`sudo`) execution can access `bpf(2)` for networking (e.g. cgroup socket filters), but tracing tools like `bpftrace` or `ftrace` cannot inspect kernel internals.

---

## 3. vCPU Scheduling, Microarchitecture & Topology

Probing `/sys/devices/system/cpu/` establishes the exact compute allocation:

| Property | Value | Systems Evidence |
| :--- | :--- | :--- |
| **vCPU Count** | 4 | `nproc` = 4 |
| **Physical Sockets** | 1 (`physical_package_id = 0` for all vCPUs) | `/sys/devices/system/cpu/cpu*/topology/physical_package_id` |
| **Core IDs** | `0, 1, 2, 3` (distinct physical cores) | `/sys/devices/system/cpu/cpu*/topology/core_id` |
| **Thread Siblings** | Each vCPU lists only itself (`0`, `1`, `2`, `3`) | `/sys/devices/system/cpu/cpu*/topology/thread_siblings_list` |
| **Core Siblings** | `0-3` | `/sys/devices/system/cpu/cpu*/topology/core_siblings_list` |
| **SMT (Hyperthreading)** | **Disabled** inside guest (`smt=false`) | Matches Firecracker `"smt": false` machine configuration |
| **CPU Frequency Scaling** | None exposed | `/sys/devices/system/cpu/cpu0/cpufreq` absent |
| **Isolated Cores** | None (`/sys/devices/system/cpu/isolated` empty) | All 4 vCPUs share default kernel scheduler queues |
| **Clocksource** | `tsc` (TSC early -> kvm-clock -> tsc) | `dmesg` confirms `clocksource: Switched to clocksource tsc` |

---

## 4. Cgroups v2 Hierarchy & Resource Quotas

Probing `/sys/fs/cgroup/` reveals how systemd organizes workloads inside the microVM:

```bash
# Mounted hierarchy
cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime,nsdelegate,memory_recursiveprot)

# Enabled controllers
cpuset cpu io memory hugetlb pids
```

### Slice Inspection:
- **`user.slice`** (holds interactive user sessions, tmux, agent turns):
  - `memory.max`: `max` (unconstrained)
  - `cpu.max`: `max 100000` (100% of 4 vCPUs bandwidth)
  - `memory.current`: `2,796,634,112` bytes (~2.60 GiB active)
- **`system.slice`** (holds system services: sshd, docker, containerd, socat, keepalives):
  - `memory.max`: `max` (unconstrained)
  - `cpu.max`: `max 100000` (unconstrained)
  - `memory.current`: `450,564,096` bytes (~429 MiB active)

### Key Takeaway:
There is **zero internal CPU throttling or memory capping** applied between user and system services. If an agent process consumes 100% CPU on all 4 vCPUs or 7 GiB of RAM, systemd will not throttle it. The microVM is treated as a single dedicated resource envelope.

---

## 5. Memory Management, Hugepages & Ballooning

Inspection of `/proc/meminfo`, `/sys/kernel/mm/`, and Virtio drivers reveals:

- **Total Usable RAM**: `8,150,116 kB` (~7.77 GiB usable out of 8,192 MiB Firecracker machine memory).
- **Pagecache / Buffers**: ~2.32 GiB cached pages (mostly SquashFS golden image pages read from `/dev/vda`).
- **Swap Subsystem**: `SwapTotal = 0 kB`. No swap partition or swap file exists. Memory exhaustion immediately invokes the Linux kernel Out-Of-Memory (OOM) killer.
- **Transparent Huge Pages (THP)**:
  - Mode: `always [madvise] never`
  - Defrag: `always defer defer+madvise [madvise] never`
  - Shmem: `always within_size advise [never] deny force`
  - **Rationale**: `madvise` avoids memory bloat and allocation stalls on 4K pages while allowing runtimes like Go and Node.js to explicitly request 2MB hugepages via `madvise(MADV_HUGEPAGE)`.
- **Virtio Balloon Driver**:
  - The driver `virtio_balloon` is loaded in the kernel (`/sys/bus/virtio/drivers/virtio_balloon/`), but **no balloon device is provisioned** on the Virtio-MMIO bus. Only 4 MMIO devices are bound (`virtio0` through `virtio3`).
  - Google does not dynamically reclaim memory from the microVM via ballooning; memory footprint is fixed at 8 GiB.
- **Kernel Samepage Merging (KSM)**:
  - `/sys/kernel/mm/ksm/run = 0` (disabled), preventing side-channel cross-workload timing attacks on shared physical host memory.

---

## 6. Synthesis: The Jules Hardware Isolation Thesis

| Defense Layer | Traditional Cloud Agent Sandboxes | Google Jules Architecture |
| :--- | :--- | :--- |
| **In-Guest Syscall Filtering** | Strict Seccomp-BPF whitelist | **None** (`# CONFIG_SECCOMP is not set`) |
| **Linux Security Modules** | AppArmor / SELinux profiles | **None** (`# CONFIG_SECURITY is not set`) |
| **Kernel Extensibility** | Restricted modprobe or eBPF tracing | **Monolithic** (`# CONFIG_MODULES is not set`) |
| **Resource Throttling** | Cgroup v2 burst quotas & memory caps | **Unconstrained** (`memory.max = max`, `cpu.max = max`) |
| **Isolation Boundary** | Software namespace / syscall interception | **KVM Hardware Virtualization (Firecracker)** |

By stripping away software-level containment layers (seccomp, LSMs, module loaders, cgroup quotas) and relying exclusively on KVM paravirtualization, Google Jules achieves two critical advantages:
1. **100% Native Linux Tooling Compatibility**: Runtimes, compilers, debuggers, browsers, and container engines run exactly as they would on bare metal without mysterious `EPERM` syscall failures.
2. **Deterministic, Impenetrable Confinement**: Workload escape requires a KVM hypervisor escape or Firecracker VMM vulnerability, rather than a kernel privilege escalation or container escape bug.
