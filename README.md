# Google Jules Systems Architecture: Empirical Sandbox Dissection

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%2024.04%20%7C%20Linux%206.8--devbox-informational.svg)](evidence/HARDENING.md)
[![Isolation `[Tier 1]`](https://img.shields.io/badge/Isolation-KVM%20MicroVM%20(Virtio--MMIO)-orange.svg)](evidence/SYSTEM_TOPOLOGY.md)
[![Control Plane `[Tier 1]`](https://img.shields.io/badge/Control%20Plane-Virtio--VSOCK%20%2B%20tmux-blueviolet.svg)](evidence/OPT_AND_HARNESS.md)
[![Storage `[Tier 1]`](https://img.shields.io/badge/Storage-SquashFS%20%2B%20OverlayFS-red.svg)](evidence/BOOT_AND_HYPERVISOR.md)
[![Methodology `[Tier 1]`](https://img.shields.io/badge/Methodology-Black--Box%20Verification-brightgreen.svg)](evidence/)

> Google engineered the agent devbox. We audited the syscalls and hypervisor.<br>
> Independent systems dissection of Google's **Jules** asynchronous coding agent execution sandbox, with empirical measurements, kernel dmesg telemetry, and runtime inspection extracted directly from inside live workload sessions.

---

## Executive Summary

Google's **Jules** is an asynchronous coding agent that interfaces directly with GitHub repositories, plans and executes tasks inside dedicated cloud development environments, and pushes code review pull requests.

This repository documents the guest execution environment from the inside out—verifying hypervisor architecture, kernel boot arguments, storage durability semantics, inter-process communication, browser automation capabilities, and structural isolation boundaries.

The architecture comprises five operational layers:

1. **Virtualization & Hardware Plane**: A paravirtualized hardware virtual machine (**KVM**) running a custom kernel (`Linux devbox 6.8.0 #1 SMP PREEMPT_DYNAMIC`). The hypervisor enforces a **PCI-free (`pci=off`) microVM topology** where all virtual devices (disks, network, vsock) are mapped via **Virtio-MMIO** registers, initialized with static kernel network routing and sub-second boot times.
2. **Storage Subsystem & Lifecycle Durability**: An immutable, read-only compressed base image (**SquashFS 4.0** on `/dev/vda`) paired with an ephemeral writable scratch disk (**ext4** on `/dev/vdb`). A custom init script (`/usr/sbin/overlay-init`) mounts an `overlayfs` uniting them and pivots the root (`pivot_root`). Task state is fully durable across turns *within* a task, but structurally ephemeral *across* separate tasks.
3. **Control Plane & Command Harness**: The host hypervisor mediates orchestration via **Virtio-VSOCK** (`vsock-stream:2:9999` for VMM lifecycle notification; `VSOCK-LISTEN:22` bridged by `socat` to localhost SSH). Execution runs inside a persistent background **`tmux`** session, using a file-piped FIFO harness in `/run/devbox-session/default/` synchronized via bash `PROMPT_COMMAND` and `inotifywait`.
4. **Tooling & Headless Automation Plane**: A comprehensive, pre-baked developer ecosystem featuring a complete **Google Chrome** (268 MB) and **Playwright** virtual environment for browser testing, alongside multi-language SDKs (Python, Node/NVM, Java, Go, Rust, Bun, C/C++, Flutter, Android SDK) audited via `/opt/environment_summary.sh`.
5. **Empirical Negative Results & Security Boundaries**:
   * **Container Execution Failure**: Containerd fails out-of-the-box (`EINVAL: filesystem not supported as upperdir`) due to kernel restrictions prohibiting nested overlayfs mounts on an underlying overlayfs root.
   * **Nested Virtualization Absent**: CPU features lack `vmx` / `svm` flags; hardware virtualization cannot be nested.
   * **Zero Hardware Bus Exposure**: `pci=off` disables PCI enumeration entirely.

---

## Provenance Framework & Classification

All statements, measurements, and logs in this study are categorized according to a strict three-tier evidential framework:

* **[Tier 1: Directly Observed]**: Directly measured via command execution, kernel outputs, dmesg logs, or filesystem inspection from within live Jules sessions.
* **[Tier 2: Architectural Inference]**: Inferred from observed configurations, boot arguments, or standard virtualization design patterns where host-side infrastructure cannot be directly queried.
* **[Tier 3: Platform Definition]**: Sourced from platform documentation, GitHub webhook behaviors, or PR interfaces; unverified from within the container boundary.

---

## Architectural Topography

```
+===================================================================================================+
|                                    1. USER / GITHUB LAYER                                         |
|   Developer Issue / PR Comment (@jules) <---------------------> Commits / PR Reviews / Reactions  |
+===================================================================================================+
                                                  │ HTTPS / Webhooks
                                                  ▼
+===================================================================================================+
|                                2. JULES ORCHESTRATION LAYER                                       |
|   +-------------------------------------------------------------------------------------------+   |
|   |  Jules Cloud Platform                                                                     |   |
|   |  - Reasoning & Planning Agent (Gemini model family)                                       |   |
|   |  - Repo Synchronizer: Clones target git repo to /app on branch jules-<task_id>-<hash>     |   |
|   |  - Hypervisor Manager: Dispatches microVM instances per task                              |   |
|   +---------------------------------------------+---------------------------------------------+   |
+=================================================│=================================================+
                                                  │ Virtio-VSOCK (CID 2) & SSH Reverse Tunnel
                                                  ▼
+===================================================================================================+
|                                3. HOST HYPERVISOR BOUNDARY                                        |
|   [ KVM MicroVM (Inferred Cloud Hypervisor / Firecracker architecture) | pci=off | 4 vCPUs | 8 GiB RAM ]   |
|                                                                                                   |
|   Virtio-MMIO Registers:                                                                          |
|   - 0xc0001000: virtio0 (vda, 4.36 GiB SquashFS Base Image)                                      |
|   - 0xc0002000: virtio1 (vdb, 100 GiB ext4 Scratch Overlay Disk)                                 |
|   - 0xc0003000: virtio2 (eth0, Virtio-Net, Static IP 192.168.0.2)                                 |
|   - 0xc0004000: virtio3 (Virtio-VSOCK, Host Channel)                                             |
+=================================================│=================================================+
                                                  │ MMIO Bus / VSOCK Streams
                                                  ▼
+===================================================================================================+
|                                  4. GUEST WORKLOAD DEVBOX                                         |
|                                                                                                   |
|   +-------------------------------------------------------------------------------------------+   |
|   |  Boot & Storage Subsystem                                                                 |   |
|   |  - init=/usr/sbin/overlay-init                                                            |   |
|   |  - Mounts /dev/vda (ro) -> /rom                                                           |   |
|   |  - Mounts /dev/vdb (rw) -> /rom/overlay                                                   |   |
|   |  - overlayfs (lower=/rom, upper=/overlay/root, work=/overlay/work) -> /merged             |   |
|   |  - pivot_root /merged /merged/rom -> Systemd /sbin/init                                  |   |
|   +-------------------------------------------------------------------------------------------+   |
|                                                                                                   |
|   +-------------------------------------------------------------------------------------------+   |
|   |  Control Plane & IPC Harness                                                              |   |
|   |  - Host Notification: systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999        |   |
|   |  - socat (PID 876): VSOCK-LISTEN:22 ──> TCP 127.0.0.1:22 (SSH Bridge)                    |   |
|   |  - sshd (PID 929): Host worker connects over VSOCK                                        |   |
|   |  - tmux server (PID 2348): Holds session 'default' (cwd: /app, JULES_SESSION_ID)          |   |
|   |  - File FIFO IPC: /run/devbox-session/default/{command,stdin,stdout,stderr}               |   |
|   |  - Liveness & Completion: inotifywait watches /run/.../stamp; PROMPT_COMMAND touches stamp|   |
|   +-------------------------------------------------------------------------------------------+   |
|                                                                                                   |
|   +-------------------------------------------------------------------------------------------+   |
|   |  Execution & Automation Engines                                                           |   |
|   |  - Headless Browser: Google Chrome (/opt/google/chrome) + Playwright (/opt/jules)         |   |
|   |  - Multi-Language Toolchain: Go 1.24, Python 3.12, Node 22, Rust, Flutter, Android SDK    |   |
|   |  - Docker Daemon: dockerd active, but container launch blocked by overlay-on-overlay     |   |
|   +-------------------------------------------------------------------------------------------+   |
+===================================================================================================+
```

---

## Subsystem Analysis

### 1. MicroVM Virtualization & Syscall Confinement

* **Kernel Command Line** `[Tier 1]`:
  ```text `[Tier 1]`
  console=ttyS0 reboot=k panic=1 pci=off init=/usr/sbin/overlay-init ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999 pci=off root=/dev/vda ro virtio_mmio.device=4K@0xc0001000:5 virtio_mmio.device=4K@0xc0002000:6 virtio_mmio.device=4K@0xc0003000:7 virtio_mmio.device=4K@0xc0004000:8
  ```
* **MicroVM Hypervisor Architecture** `[Tier 1]`:
  * `pci=off`: PCI bus probing is explicitly disabled. Traditional PCI host bridges and buses do not exist.
  * **Virtio-MMIO**: Device enumeration occurs entirely via 4 fixed memory-mapped I/O windows (`0xc0001000` through `0xc0004000`, IRQs 5-8). This topology suggests an inference of a purpose-built microVM hypervisor such as **Cloud Hypervisor** or **Firecracker**, optimized for minimal memory footprint.
* **CPU & Microarchitecture** `[Tier 1]`:
  * 4 vCPUs backed by `Intel(R) Xeon(R) Processor @ 2.30GHz`.
  * Feature flags include `avx`, `avx2`, `f16c`, `bmi1`, `bmi2`, `erms`, `aes`, `rdrand`.
  * **Nested Virtualization**: Disabled (`vmx` and `svm` are absent from `/proc/cpuinfo`).
* **Static Network Boot** `[Tier 1]`:
  * Boot networking bypasses DHCP: `ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off`. Network configuration is established instantaneously at kernel initialization.

---

### 2. Storage Subsystem & Lifecycle Durability

The guest storage architecture is decoupled into an immutable golden image and a discarded upper scratch layer:

```
+-------------------------------------------------------------------------+
|                              Rootfs (/)                                 |
|         (Mounted as overlayfs by /usr/sbin/overlay-init)                |
+------------------------------------+------------------------------------+
                                     │
           ┌─────────────────────────┴─────────────────────────┐
           ▼                                                   ▼
+------------------------------------+   +--------------------------------+
|      Upper Layer (/overlay/root)   |   |       Lower Layer (/rom)       |
|  - Writable ext4 (/dev/vdb)        |   |  - Read-Only SquashFS (/dev/vda)
|  - 100 GiB capacity, 93 GiB free   |   |  - 4.36 GiB compressed golden  |
|  - Holds all task session writes   |   |  - Clean Ubuntu 24.04 + tools  |
+------------------------------------+   +--------------------------------+
```

* **The Boot Init Script (`/usr/sbin/overlay-init`)** `[Tier 1]`:
  ```sh
  #!/bin/sh
  # FIXME(feyu): using the label during init apparently doesn't work.
  # Use /dev/vdb for now.
  /bin/mount /dev/vdb /overlay
  mkdir -p /overlay/root /overlay/work /overlay/root/rom

  /bin/mount \
      -o noatime,lowerdir=/,upperdir=/overlay/root,workdir=/overlay/work \
      -t overlay "overlayfs:/overlay/root" /merged

  /usr/sbin/pivot_root /merged /merged/rom
  rmdir /overlay /merged
  exec /usr/sbin/init $@
  ```
* **Cross-Task Durability Semantics** `[Tier 1]`:
  * **Within a Task**: Modifications across turns (files in `/tmp`, `/home/jules`, and `/app`) persist perfectly in the `/dev/vdb` upperdir.
  * **Across Separate Tasks**: As proven by [`evidence/CROSS_TASK_CHECK.md`](evidence/CROSS_TASK_CHECK.md), markers written during task `14165408129265143467` disappeared completely in task `10448450951705239643`. However, `tune2fs -l /dev/vdb` reveals the filesystem was created 2026-03-06, meaning the per-task isolation is implemented via host-side snapshots of the backing image, not a fresh format per task. Furthermore, `uptime -s` shows non-uniform kernel freshness across the fleet (mixing fresh boots with ~213-day uptimes), though isolation semantics remain intact.

---

### 3. Control Plane & Command Execution Harness

Google avoids external agent daemon bloat by reusing battle-tested Unix utilities (`socat`, `sshd`, `tmux`, `inotifywait`):

```
[Host Hypervisor]
       │ (Virtio-VSOCK Stream, Host CID 2)
       ▼
socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22 (PID 876)
       │
sshd worker (PID 929)
       ├─ inotifywait -e create,moved_to --include /stamp$ /run/devbox-session/default
       └─ tail --pid 2349 -f /dev/null
       ▲
       │ (Synchronized via tmpfs FIFO files)
       ▼
tmux server (PID 2348: new-session -d -s default -c /app -e JULES_SESSION_ID=...)
   └─ bash (PID 2349)
         └─ source /run/devbox-session/default/command < stdin > stdout 2> stderr
            PROMPT_COMMAND: echo $? > exit_code && touch stamp
```

* **VSOCK SSH Proxy** `[Tier 1]`: `devbox-ssh-over-vsock.service` maps `VSOCK-LISTEN:22` to `TCP 127.0.0.1:22`. The unit file explicitly documents the rationale:
  > *"For systemd > 256 there is also a systemd-ssh-generator(8) that can configure sshd over vsock. We use a somewhat old ubuntu for guest that has systemd 255. So the approach here is slightly more portable... c.f. https://libvirt.org/ssh-proxy.html#guest-os-requirements"*
* **VMM Notification Credential** `[Tier 1]`: The kernel passes `systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999` to allow guest initialization services to report status back to the hypervisor management plane on VSOCK CID 2, port 9999.
* **Interactive Tmux Session** `[Tier 1]`: Rather than executing transient SSH commands, the host binds to a persistent `tmux` session named `default` running in `/app` with `JULES_SESSION_ID` and `GIT_TERMINAL_PROMPT=0`.
* **Execution Synchronization** `[Tier 1]`:
  1. The host agent writes the instruction script to `/run/devbox-session/default/command`.
  2. The interactive shell sources the script with I/O redirected to `/run/devbox-session/default/{stdin,stdout,stderr}`.
  3. When execution finishes, bash's `PROMPT_COMMAND` triggers:
     ```bash
     PROMPT_COMMAND='__CODExx__=$?; echo $__CODExx__ > /run/devbox-session/default/exit_code && touch /run/devbox-session/default/stamp; unset PROMPT_COMMAND;'
     ```
  4. `touch stamp` notifies `inotifywait` on the SSH worker, which harvests the outputs and notifies the host.

---

### 4. Tooling & Headless Automation Plane

The base image contains an expansive, pre-installed toolchain matrix verified by Google's baked-in `/opt/environment_summary.sh` script:

* **Headless Browser & E2E Testing** `[Tier 1]`:
  * **Google Chrome**: Full production binary at `/opt/google/chrome/chrome` (268 MB), complete with Widevine CDM, SwiftShader, and locale paks.
  * **Playwright**: Dedicated Python virtualenv managed via `pipx` at `/opt/jules/playwright/bin/playwright`.
  * **Use Case**: Enables Jules to execute end-to-end visual tests, render frontend web applications, and debug DOM state autonomously.
* **Multi-Language Runtimes** `[Tier 1]`:
  * **Go**: `go1.24.3 linux/amd64`
  * **Python**: Python 3.12.13 (pyenv, pipx, poetry, uv, ruff, black, mypy, pytest)
  * **Node.js**: v22.22.1 (NVM, npm, pnpm, yarn, prettier, eslint)
  * **Rust**: `rustc` / `cargo 1.94.0` (rustup)
  * **C/C++**: GCC 13.3.0, Clang, CMake, Ninja, Conan 2
  * **Java**: JDK, Maven, Gradle
  * **Mobile / Cross-Platform**: Android SDK (`sdkmanager`), Flutter
  * **Web**: Bun, PHP (Composer), Ruby (Bundler), .NET SDKs

---

### 5. Empirical Negative Results & Constraints

* **1. Docker Container Execution Failure (Overlay-on-Overlay)** `[Tier 1]`:
  * **Observation**: Running `docker run --rm alpine uname -a` successfully pulled the image from Docker Hub (confirming registry egress), but failed immediately at runtime:
    ```text `[Tier 1]`
    docker: Error response from daemon: failed to mount /tmp/containerd-mount...: mount source: "overlay", ... err: invalid argument
    ```
  * **Kernel Confirmation**: Kernel `dmesg` confirmed the exact failure point:
    ```text `[Tier 1]`
    [18408631.151288] overlay: filesystem on /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/2/work not supported as upperdir
    ```
  * **Systems Root Cause**: The root filesystem `/` is already an `overlayfs`. Containerd's default `overlayfs` snapshotter attempts to mount an upperdir residing on this underlying overlayfs. The Linux kernel explicitly rejects using an overlayfs as an upper layer for another overlayfs (`EINVAL`).
  * **Implication**: Jules cannot execute Docker containers in the devbox unless dockerd is manually reconfigured with the `vfs` or `fuse-overlayfs` driver.
* **2. Absence of Nested Virtualization** `[Tier 1]`:
  * `/proc/cpuinfo` flags contain neither `vmx` (Intel) nor `svm` (AMD).
  * Hardware-accelerated nested KVM microVMs or Android QEMU emulators cannot be spawned.
* **3. Absence of PCI Bus** `[Tier 1]`:
  * `pci=off` disables PCI scanning; `lspci` command fails and PCI sysfs trees are unpopulated.

---

## Comparative Matrix: Google Jules vs. Gemini Spark

A comparative analysis of Google.s two primary agent execution environments (Note: Spark-side claims are sourced from a different external teardown testimony, not direct observation here):

| Architectural Dimension | Google Jules Devbox | Gemini Spark Sandbox |
| :--- | :--- | :--- |
| **Virtualization Primitive** | Hardware Virtual Machine (**KVM**) | Process-level Syscall Emulation (**gVisor / Sentry**) |
| **Hypervisor Architecture** | Virtio-MMIO MicroVM (`pci=off`) | gVisor Gofer + Sentry (Linux 4.19 ABI) |
| **Privilege Model** | User `jules` (UID 1001) with **passwordless `sudo`** | Unprivileged `spark` (UID 1235), `CapEff: 0x0` |
| **Network Egress** | Open outbound HTTPS (GitHub, npm, PyPI, Go, Docker) | Strict Air-Gap (loopback only, zero routes) |
| **Host-to-Guest IPC** | **Virtio-VSOCK** (CID 2, port 22 SSH + port 9999 VMM notify) | `runsc exec` + Unix socket bridge (`/ipc/remy_memfs_proxy.sock`) |
| **Execution Supervisor** | Persistent `tmux` session + file FIFO (`devbox-session`) | In-memory **FastAPI / Uvicorn** daemon (`dynamo_exec.py`) |
| **Storage Architecture** | SquashFS `/rom` (ro) + ext4 `/overlay` (rw) via `pivot_root` | Ephemeral root overlayfs + Plan 9 (9P) persistent host mounts |
| **Cognitive Memory Plane** | Ephemeral per task; no in-guest vector memory FUSE | In-guest FUSE daemon (**Jetski `mfs`**) connected to host Dumbo/Remy |
| **Visual Automation** | Headless Google Chrome + Playwright | 1440p TigerVNC virtual display + `ffmpeg` + `xdotool` |
| **Container Engine** | `dockerd` running (default overlay snapshotter fails; vfs works) | Container runtime disallowed inside gVisor |

---

## Evidence Index & Provenance Map

All conclusions in this report are substantiated by raw outputs committed in this repository:

| Artifact | Description | Key Evidence |
| :--- | :--- | :--- |
| [`evidence/HARDENING.md`](evidence/HARDENING.md) | Initial baseline probes | Namespaces (`uid_map`), running systemd units, public egress verification, `/opt` listing |
| [`evidence/OPT_AND_HARNESS.md`](evidence/OPT_AND_HARNESS.md) | Runtime tooling & process tree | `/opt/environment_summary.sh`, Chrome/Playwright census, `pstree` (`socat`, `tmux`, `inotifywait`), VSOCK unit file |
| [`evidence/SYSTEM_TOPOLOGY.md`](evidence/SYSTEM_TOPOLOGY.md) | Hypervisor & storage topology | Kernel `/proc/cmdline` (`pci=off`, `virtio_mmio`), `lsblk` (SquashFS + ext4), Docker overlay mount failure |
| [`evidence/BOOT_AND_HYPERVISOR.md`](evidence/BOOT_AND_HYPERVISOR.md) | Boot script & kernel proof | `/usr/sbin/overlay-init` source, kernel `dmesg` overlay error, MMIO resource allocations, `/proc/cpuinfo` flags |
| [`evidence/TASK_LIFECYCLE.md`](evidence/TASK_LIFECYCLE.md) | Session interaction mechanics | `PROMPT_COMMAND` exit-code capture, git branch mechanics |
| [`evidence/PERSISTENCE.md`](evidence/PERSISTENCE.md) & [`evidence/CROSS_TASK_CHECK.md`](evidence/CROSS_TASK_CHECK.md) | Storage durability boundary | In-task state persistence vs. cross-task ephemeral isolation verification |
| [`evidence/ENVIRONMENT.md`](evidence/ENVIRONMENT.md) | OS & toolchain discovery | Ubuntu 24.04 release, kernel build metadata, Go/Python/Node baseline |
| [`evidence/RUNTIME_AUDIT.md`](evidence/RUNTIME_AUDIT.md) | Runtime execution audit | Package mirrors (us-central1 GCE), storage I/O, Chrome DOM rendering, VFS container testing |
| [`evidence/UPTIME_AND_STORAGE_PROBE.md`](evidence/UPTIME_AND_STORAGE_PROBE.md) | Uptime and VDB storage | `uptime -s` and `tune2fs -l /dev/vdb` verifying host-side vdb snapshots and non-uniform kernel freshness |

---

## License

This empirical systems study and all associated evidence files are released under the [MIT License](LICENSE).
