# Live Empirical Audit Report (Out-of-Band Direct Extraction)

> **Branch:** `audit/antigravity-live-extraction`<br>
> **Methodology:** Direct, non-invasive out-of-band extraction over authenticated Tailcat WireGuard SSH tunnel (`tailcat ssh root@...`) while the devbox microVM was active.<br>
> **Target System:** Google Jules Cloud Devbox (Linux `devbox 6.8.0 #1 SMP PREEMPT_DYNAMIC Fri Feb 20 20:38:43 UTC 2026 x86_64`).

---

## 1. Key Architectural Breakthroughs

### A. ACPI DSDT Disassembly & `VM_Gen_Counter` (`VMGenID`)
We extracted the raw binary ACPI tables from `/sys/firmware/acpi/tables/` and disassembled the DSDT using `iasl` (Intel ASL+ Compiler/Disassembler). The disassembled source is archived at [`acpi_tables/DSDT.dsl`](acpi_tables/DSDT.dsl):

```asl
DefinitionBlock ("", "DSDT", 2, "FIRECK", "FCVMDSDT", 0x00000000)
{
    // Linaro Virtio-MMIO devices (vda, vdb, eth0, vsock)
    Device (V000) { Name (_HID, "LNRO0005") Name (_CRS, ResourceTemplate () { Memory32Fixed (ReadWrite, 0xC0001000, 0x1000) Interrupt (..., 5) }) }
    Device (V001) { Name (_HID, "LNRO0005") Name (_CRS, ResourceTemplate () { Memory32Fixed (ReadWrite, 0xC0002000, 0x1000) Interrupt (..., 6) }) }
    Device (V002) { Name (_HID, "LNRO0005") Name (_CRS, ResourceTemplate () { Memory32Fixed (ReadWrite, 0xC0003000, 0x1000) Interrupt (..., 7) }) }
    Device (V003) { Name (_HID, "LNRO0005") Name (_CRS, ResourceTemplate () { Memory32Fixed (ReadWrite, 0xC0004000, 0x1000) Interrupt (..., 8) }) }

    // Generic Event Device (GED) on IRQ 9
    Device (_SB.GED)
    {
        Name (_HID, "ACPI0013")
        Name (_CRS, ResourceTemplate () { Interrupt (ResourceConsumer, Edge, ActiveHigh, Exclusive) { 0x00000009 } })
        Method (_EVT, 1, Serialized)
        {
            If ((Arg0 == 0x09))
            {
                Notify (\_SB.VGEN, 0x80) // Status Change: VM Fork / Snapshot Resume
            }
        }
    }

    // VM Generation Counter
    Device (_SB.VGEN)
    {
        Name (_HID, "FCVMGID")
        Name (_CID, "VM_Gen_Counter")
        Name (_DDN, "VM_Gen_Counter")
        Name (ADDR, Package (0x02) { 0x000DFFF0, 0x00000000 })
    }
}
```

* **Root Cause of `random: crng reseeded due to virtual machine fork`**:
  Firecracker does not inject synthetic kernel syscalls to notify the guest of a snapshot restore. Instead, upon unpausing or cloning the VM, Firecracker pulses **IRQ 9** to the ACPI Generic Event Device (`ACPI0013`), which triggers `Notify (\_SB.VGEN, 0x80)` on the Virtual Machine Generation Counter (`FCVMGID` at memory address `0x000DFFF0`). Linux's `drivers/virt/vmgenid.c` driver intercepts this hardware event and immediately triggers an in-kernel entropy reseed.

---

### B. The Dual Identity: `jules` vs `swebot`
Examination of `/etc/passwd` ([`security_and_auth/passwd_group.txt`](security_and_auth/passwd_group.txt)) reveals:

```text
jules:x:1001:1001::/home/jules:/bin/bash
swebot:x:1001:1001::/home/jules:/bin/bash
```

* `jules` and `swebot` share the exact same UID (`1001`), primary GID (`1001`), and home directory (`/home/jules`).
* Both accounts are granted passwordless root privileges in `/etc/sudoers.d/` (`NOPASSWD: ALL`).
* **Architectural Rationale**: Google divides responsibilities:
  1. `swebot` is the non-interactive orchestration identity connecting over the Virtio-VSOCK SSH bridge.
  2. `jules` is the user identity that owns `/app` and runs interactive commands inside the persistent `tmux` session.

---

### C. Systemd Credential Injection (`vmm.notify_socket`)
* The kernel cmdline specifies: `systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999`.
* Inspection of the filesystem ([`systemd_and_ipc/vmm_notify_socket.txt`](systemd_and_ipc/vmm_notify_socket.txt)) confirms systemd PID 1 decrypts and mounts this credential into a dedicated tmpfs:
  ```text
  /run/credentials/@system/vmm.notify_socket -> "vsock-stream:2:9999"
  ```
* Probing **Host CID 2 Port 9999** via `socket(AF_VSOCK, SOCK_STREAM)` returned:
  ```text
  VSOCK CID 2 Port 9999: CLOSED ([Errno 104] Connection reset by peer)
  ```
  The connection was immediately reset with `RST` rather than timing out or returning `ECONNREFUSED`. This confirms the host Firecracker VMM supervisor is actively bound to port 9999 and enforces strict notify protocol semantics.

---

### D. Host Gateway Port & Git Reverse Proxy Audit
A full TCP port sweep of the host gateway (`192.168.0.1`) revealed:
```text
Port 22: CLOSED
Port 53: OPEN   (DNS Forwarder)
Port 80: CLOSED
Port 443: CLOSED
Port 8080: OPEN (Python BaseHTTP/0.6 Git Reverse Proxy)
Port 9999: CLOSED
```

* **Zero-Secret In-Guest Storage**:
  Inspection of global git configs ([`network_and_proxy/git_configs.txt`](network_and_proxy/git_configs.txt)) showed:
  ```text
  user.name=google-labs-jules[bot]
  user.email=161369871+google-labs-jules[bot]@users.noreply.github.com
  core.hookspath=/dev/null
  ```
  All git clone and push operations are rewritten via:
  `url.http://git@192.168.0.1:8080/.insteadOf https://github.com/`
  The host-side Python reverse proxy injects short-lived GitHub App installation tokens into outbound HTTPS git packets. As a result, **no GitHub tokens, PATs, or secrets ever enter the guest filesystem.**
* **Security Hardening**:
  `core.hooksPath /dev/null` is enforced to prevent untrusted cloned repositories from executing arbitrary pre-commit or post-checkout scripts outside the monitored agent harness.

---

### E. The `swebot` Supervisor Harness State Machine
Inspection of `/proc/*/cmdline` captured the exact supervisor script executed by `swebot` on the SSH worker:

```bash
bash -c echo "${BASHPID}"
RUN_ROOT_DIR=/run/devbox-session/default
PANE_PID="<tmux_pane_pid>"

sudo mkdir -m777 -p "${RUN_ROOT_DIR}"
coproc inw {
    LC_ALL=C exec inotifywait -e create,moved_to --include '/stamp$' "${RUN_ROOT_DIR}" 2>&1
}
set -m
(
    if ps -p ${PANE_PID} > /dev/null; then
      tail --pid "${PANE_PID}" -f /dev/null
    fi
    touch "${RUN_ROOT_DIR}/stamp"
) &
pane_waiter=$!

while IFS= read -r -u "${inw[0]}" line 2>/dev/null; do
    if [ "$line" = "Watches established." ]; then
        break
    fi
done
if [ -e "${RUN_ROOT_DIR}/stamp" ]; then
    kill "$inw_PID"
else
    wait -n
fi
kill -- "-$pane_waiter" || exit 0
```

1. The host SSH worker uses bash `coproc` to spawn `inotifywait` watching `/run/devbox-session/default/stamp`.
2. A secondary subshell watches the tmux pane PID with `tail --pid <PANE_PID> -f /dev/null` as a fallback safety exit.
3. Once the command completes inside tmux, bash `PROMPT_COMMAND` writes the exit code to `exit_code` and executes `touch stamp`.
4. The `inotifywait` watcher fires, waking up the host worker to immediately retrieve stdout/stderr.

---

### F. SquashFS Base Image Layering
* `/rom` contains the immutable lowerdir of the `overlayfs`:
  ```text
  drwxr-xr-x 27 root root 348 Jan  1  1970 /rom
  ```
* All file timestamps in `/rom` are clamped to Unix epoch `0` (`1970-01-01`), proving hermetic and reproducible image assembly.
* Pre-baked toolchains inside `/rom/opt/`:
  - `android-sdk`
  - `flutter`
  - `google` (Chrome 145)
  - `jules` (Playwright virtualenv)
  - `environment_summary.sh`

---

### G. Monolithic Kernel Security & Unconstrained Cgroups v2
Direct probe of `/proc/config.gz` and cgroup v2 sysfs controllers revealed:
* `# CONFIG_SECCOMP is not set`: Complete absence of kernel seccomp. The agent can invoke any Linux x86_64 system call without filter overhead or interception.
* `# CONFIG_MODULES is not set`: The kernel is 100% monolithic. Loadable kernel modules cannot be inserted, eliminating LKM persistence.
* `unprivileged_bpf_disabled = 2`: eBPF is permanently locked against unprivileged execution.
* Unified Cgroups v2: Both `user.slice` and `system.slice` have `memory.max = max` and `cpu.max = max 100000`, proving zero in-guest CPU throttling or memory capping.

---

### H. OverlayFS Root Credential Bypass & Disk-Full Saturation Mechanics
Direct empirical exhaustion of the `/dev/vdb` ext4 scratch partition uncovered:
* **The Root Reservation Bypass**: Ext4's default 5.0% root reservation (`1,310,720` blocks = 5.016 GiB) strictly blocks direct writes to `/rom/overlay` when `f_bavail == 0`. However, writes traversing the root OverlayFS (`/`) bypass this check entirely because `ovl_write_iter()` calls `override_creds(&init_cred)` using the mounter's root credentials (UID 0). Unprivileged user `jules` successfully consumed an extra 5,169 MB into the reservation pool down to the physical metadata floor (`Free = 0.02 GiB`).
* **Fault Isolation via Tmpfs Decoupling**: Under 100% ext4 saturation (`errno 28 ENOSPC`), the microVM remains completely stable. Memory-backed tmpfs mounts (`/run` housing the `/run/devbox-session/default/` host FIFO harness, and `/var/lib/systemd` housing journald) operate unaffected in RAM. Firecracker does not pause vCPUs, ext4 remains mounted read-write (`errors=continue`), and Tailcat SSH ingress stays responsive. Full report: [`../../evidence/DISK_FULL_AND_STORAGE_EXHAUSTION.md`](../../evidence/DISK_FULL_AND_STORAGE_EXHAUSTION.md).

---

## 2. Directory Index of Harvested Telemetry

| Category Directory | Key Files | Description |
| :--- | :--- | :--- |
| [`kernel_and_hypervisor/`](kernel_and_hypervisor/) | `dmesg_full.txt`, `cmdline.txt`, `cpuinfo.txt`, `iomem.txt`, `virtio_devices.txt`, `sysctl_all.txt`, `vcpu_topology.txt`, `ebpf_capabilities.txt`, `cgroups_v2_quotas.txt`, `memory_and_hugepages.txt`, `kernel_security_config.txt` | Complete kernel dmesg, boot flags, Virtio-MMIO registers, kernel security config, vCPU topology, eBPF, and cgroups v2 |
| [`acpi_tables/`](acpi_tables/) | `DSDT.dsl`, `acpi_tables.tar.gz`, `tables_listing.txt` | Disassembled ASL source of Firecracker DSDT and raw ACPI binary tarball |
| [`storage_and_boot/`](storage_and_boot/) | `mounts_and_mountinfo.txt`, `rom_listing.txt`, `vdb_tune2fs.txt`, `overlay_init.sh` | OverlayFS mount table, `/rom` tree, ext4 `/dev/vdb` filesystem superblock |
| [`systemd_and_ipc/`](systemd_and_ipc/) | `vmm_notify_socket.txt`, `devbox_session_listing.txt`, `supervisor_processes.txt`, `ss_vsock.txt` | Systemd credentials, tmux FIFO harness files, `swebot` supervisor scripts |
| [`network_and_proxy/`](network_and_proxy/) | `host_gateway_ports.txt`, `proxy_headers.txt`, `git_configs.txt`, `vsock_cid2_probe.txt` | Port scan of 192.168.0.1, Python Git reverse proxy headers, VSOCK probes |
| [`security_and_auth/`](security_and_auth/) | `passwd_group.txt`, `sudoers.txt`, `capabilities.txt`, `sshd_config.txt`, `host_keys.txt` | Dual `jules`/`swebot` user definitions, sudoers policies, Linux capabilities |
