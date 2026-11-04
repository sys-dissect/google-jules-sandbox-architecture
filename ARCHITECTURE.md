# ARCHITECTURE SPECIFICATION: GOOGLE JULES EXECUTION SANDBOX

**Document Status:** Publication-Grade Architectural Whitepaper
**Target Platform:** Google Jules Asynchronous Coding Agent Devbox
**Reference Kernel:** `Linux devbox 6.8.0 #1 SMP PREEMPT_DYNAMIC (feyu@feyu-encarta.c.googlers.com)`
**Hypervisor Engine:** AWS Firecracker (ACPI: `FIRECK` / `FCAT 20240119`)

---

## Abstract

This specification details the comprehensive systems architecture of Google Jules, Google’s cloud-hosted asynchronous software engineering agent. Unlike traditional container sandboxes or gVisor syscall-emulated isolation wrappers (e.g. Gemini Spark), Google Jules executes inside dedicated, hardware-isolated KVM microVMs powered by AWS Firecracker.

Through internal empirical telemetry, forensic superblock audits, ACPI table disassembly, and process tracing, this whitepaper uncovers the 5 operational layers supporting Jules:
1. **Virtualization & Hardware Isolation**: Strict PCI-free (`pci=off`) microVM topology with Virtio-MMIO registers, x86_64 TSC clocksource, and sub-second warm-resumption mechanics.
2. **Storage Subsystem & Ephemeral Lifecycle**: Hybrid dual-disk architecture combining an immutable SquashFS 4.0 golden image with an ext4 copy-on-write scratch layer orchestrated via `/usr/sbin/overlay-init` and `pivot_root`.
3. **Control Plane & Command Harness**: AF_VSOCK-based hypervisor-to-guest orchestration, socat-bridged SSH ingress, and an asynchronous headless `tmux` FIFO harness synchronized with `inotifywait`.
4. **Networking & Transparent Reverse Git Proxy**: Static kernel boot configuration, transparent host-side Python Git OAuth injection (`devbox-gateway.internal:8080`), and unthrottled GCP `us-central1` public NAT egress.
5. **Security Model & Isolation Philosophy**: Hardware hypervisor confinement favoring high guest privilege (unrestricted root/sudo, unconfined cgroups v2, no in-guest LSMs) paired with impenetrable boundary protection.

---

## 1. Subsystem Breakdown (The 5 Operational Layers)

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
|   [ KVM MicroVM (AWS Firecracker | ACPI: FIRECK / FCAT) | pci=off | 4 vCPUs | 8 GiB RAM ]          |
|                                                                                                   |
|   Virtio-MMIO Registers:                                                                          |
|   - 0xc0001000: virtio0 (vda, 4.36 GiB SquashFS Base Image)                                      |
|   - 0xc0002000: virtio1 (vdb, 100 GiB ext4 Scratch Overlay Disk)                                 |
|   - 0xc0003000: virtio2 (eth0, Virtio-Net, Static IP 192.168.0.2)                                 |
|   - 0xc0004000: virtio3 (Virtio-VSOCK, Host CID 2, Guest CID 123)                                 |
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
|   |  - Host Notification: systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999 (CID 2)|   |
|   |  - socat (PID 876): VSOCK-LISTEN:22 ──> TCP 127.0.0.1:22 (SSH Bridge on Guest CID 123)   |   |
|   |  - sshd (PID 929): Host orchestrator 'swebot@notty' connects over VSOCK                   |   |
|   |  - tmux server (PID 2348): Holds session 'default' (cwd: /app, JULES_SESSION_ID)          |   |
|   |  - File FIFO IPC: /run/devbox-session/default/{command,stdin,stdout,stderr}               |   |
|   |  - Liveness & Completion: inotifywait watches /run/.../stamp; PROMPT_COMMAND touches stamp|   |
|   +-------------------------------------------------------------------------------------------+   |
|                                                                                                   |
|   +-------------------------------------------------------------------------------------------+   |
|   |  Execution & Automation Engines                                                           |   |
|   |  - Headless Browser: Google Chrome (/opt/google/chrome) + Playwright (/opt/jules)         |   |
|   |  - Multi-Language Toolchain: Go 1.24, Python 3.12, Node 22, Rust, Flutter, Android SDK    |   |
|   |  - Docker Daemon: dockerd active (overlay-on-overlay fails, vfs storage driver succeeds)  |   |
|   |  - Interactive Tunnel: Tailcat WireGuard DERP relay allows authenticated developer ingress|   |
|   +-------------------------------------------------------------------------------------------+   |
+===================================================================================================+
```

---

### Layer 1: Virtualization & Hardware Isolation

The compute isolation layer is rooted in Linux KVM paravirtualization orchestrated by AWS Firecracker:

* **MicroVM Hypervisor Identification**:
  * ACPI signature verification extracted from `/sys/firmware/acpi/tables/`:
    * RSDP OEM ID: `FIRECK`
    * Table Signatures: `FCMVXSDT` (XSDT), `FCVMFADT` (FADT), `FCVMDSDT` (DSDT), `FCVMMADT` (MADT), `FCMVMCFG` (MCFG)
    * Creator ID: `FCAT` (Revision `20240119`).
* **Kernel Command-Line Parameters**:
  ```text
  console=ttyS0 reboot=k panic=1 pci=off init=/usr/sbin/overlay-init ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999 pci=off root=/dev/vda ro virtio_mmio.device=4K@0xc0001000:5 virtio_mmio.device=4K@0xc0002000:6 virtio_mmio.device=4K@0xc0003000:7 virtio_mmio.device=4K@0xc0004000:8
  ```
* **Bus Architecture (`pci=off`)**:
  * The traditional PCI hierarchy is completely suppressed.
  * Device addressing operates via 4 Virtio-MMIO memory-mapped windows:
    * `0xc0001000` (IRQ 5): Block device `virtio0` (`/dev/vda`, read-only SquashFS base).
    * `0xc0002000` (IRQ 6): Block device `virtio1` (`/dev/vdb`, read-write ext4 overlay).
    * `0xc0003000` (IRQ 7): Network device `virtio2` (`eth0`, Virtio-Net).
    * `0xc0004000` (IRQ 8): Socket device `virtio3` (Virtio-VSOCK).
* **Hardware Compute Allocation**:
  * 4 vCPUs allocated from host `Intel(R) Xeon(R) Processor @ 2.30GHz` (Haswell-EP microarchitecture, 1 thread per core, SMT disabled in guest).
  * Memory: 8 GiB RAM (7.8 GiB usable).
  * Clocksource: `tsc` (Time Stamp Counter).
  * Absence of nested virtualization (`vmx`/`svm` flags disabled).
* **ACPI Hardware Wiring & VM Fork Detection**:
  * Disassembly of the ACPI DSDT (`FCVMDSDT`) reveals the Linaro Virtio-MMIO devices (`LNRO0005`) and the ACPI Generic Event Device (`ACPI0013`, IRQ 9).
  * The GED directly notifies device `_SB.VGEN` (`FCVMGID`) mapped at physical memory address `0x000DFFF0` (the VM Generation Counter / `VM_Gen_Counter`).
  * When Firecracker thaws or forks a microVM snapshot, an ACPI interrupt fires on IRQ 9; Linux's `drivers/virt/vmgenid.c` intercepts the hardware notification to trigger `random: crng reseeded due to virtual machine fork`. This guarantees cryptographic entropy uniqueness across cloned microVM instances.
* **Dual User Identity Aliasing**:
  * `/etc/passwd` defines two distinct usernames sharing the identical UID/GID `1001:1001` and home directory `/home/jules`:
    * `swebot`: Used exclusively by the host orchestrator for remote SSH connection over VSOCK (`sshd: swebot@notty`).
    * `jules`: Used by the interactive shell environment executing inside the headless tmux session (`USER=jules`, `HOME=/home/jules`).
  * This provides clean separation of concerns between the host execution harness and the agent's user environment without needing complex privilege escalation.

---

### Layer 2: Storage Subsystem & Ephemeral Lifecycle

Storage decouples immutable distribution state from per-task ephemeral writes:

1. **Physical Device Mapping**:
   * `/dev/vda`: Read-only SquashFS 4.0 image (4.36 GiB compressed footprint, blocksized at 128 KiB xz compression) containing Ubuntu 24.04 and all pre-baked SDK toolchains.
   * `/dev/vdb`: 100 GiB ext4 sparse scratch disk (92 GiB available out of 98 GiB usable capacity on 100 GiB block device; volume label `overlay`).
2. **Custom Init Pivoting (`/usr/sbin/overlay-init`)**:
   ```sh
   #!/bin/sh
   /bin/mount /dev/vdb /overlay
   mkdir -p /overlay/root /overlay/work /overlay/root/rom

   /bin/mount \
       -o noatime,lowerdir=/,upperdir=/overlay/root,workdir=/overlay/work \
       -t overlay "overlayfs:/overlay/root" /merged

   /usr/sbin/pivot_root /merged /merged/rom
   rmdir /overlay /merged
   exec /usr/sbin/init $@
   ```
3. **Durability Semantics & Cross-Task Isolation**:
   * **Intra-Task Turn Durability**: Mutations to filesystem state (files in `/app`, `/tmp`, `/home/jules`) persist reliably across agent turns within a task on the `/dev/vdb` upperdir.
   * **Cross-Task Ephemeral Discard**: Across separate tasks, environments are completely isolated. Forensic examination via `tune2fs -l /dev/vdb` proves the ext4 filesystem was created on `Fri Mar 6 17:10:25 2026`. Google manages scratch durability via copy-on-write snapshot forks of base disk images rather than invoking `mkfs.ext4` dynamically per task.
4. **Base Image Build Provenance & Golden Snapshot Timeline**:
   Forensic audit of build logs (`/rom/var/log/bootstrap.log`) reconstructs the exact build pipeline Google used to create the Jules devbox base image:
   * `2026-02-10 14:05 UTC`: Base OS bootstrap via `debootstrap noble` from `ftpmaster.internal`.
   * `2026-02-20 20:38 UTC`: Custom Linux 6.8 kernel compiled by `feyu@feyu-encarta.c.googlers.com` with GCC 15.2.
   * `2026-03-02 16:40 UTC`: Core SDKs baked (Go 1.24, Python 3.12, Node 22, Rust, Android SDK, Chrome 145).
   * `2026-03-06 16:39 UTC`: Final package upgrades (`libnss3`).
   * `2026-03-06 17:10 UTC`: Golden SquashFS 4.0 generation and ext4 scratch formatting (`tune2fs`).
   * **Deterministic Superblock**: SquashFS 4.0 superblock audit confirms magic `0x73717368`, 330,916 inodes, 128 KiB XZ blocks, and Unix epoch `0` (`1970-01-01T00:00:00Z`) creation timestamp for hermetic build reproducibility.
5. **Container Runtime & OverlayFS Architecture**:
   * **The Overlay-on-Overlay Constraint**: Out of the box, standard Docker commands (`docker run --rm alpine`) fail during container initialization (`failed to mount ... invalid argument`). Kernel dmesg logs reveal the exact cause: `overlay: filesystem on /var/lib/containerd/... not supported as upperdir`. Because `/var/lib/containerd` resides on the `/` overlayfs root, containerd attempts to mount a nested overlayfs with an overlayfs upperdir, which Linux kernel 6.8 VFS strictly disallows (`EINVAL`).
   * **Verified Solution 1 (VFS Driver Fallback)**: Starting dockerd with `--storage-driver=vfs` completely bypasses overlay nesting, though it sacrifices copy-on-write deduplication.
   * **Verified Solution 2 (Native Ext4 Direct Mounting)**: Because the raw ext4 scratch disk is directly accessible at `/rom/overlay`, starting containerd pointing directly to the underlying ext4 partition (`containerd --root /rom/overlay/ctrd-root`) allows native Linux kernel `overlayfs` containers to run at 100% full hardware speed with zero I/O performance degradation.

---

### Layer 3: Control Plane & Command Execution Harness

The control plane avoids heavy agent daemons inside the guest by coupling standard Linux IPC primitives:

1. **Virtio-VSOCK Socket Communication (`AF_VSOCK`)**:
   Communication over VSOCK does not use IP addresses or Ethernet frames. It addresses endpoints using CID (Context ID) and a Port (`AF_VSOCK = 40`):
   * **Host CID**: `2` (listening on port 9999 for VMM lifecycle notification: `systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999`).
   * **Guest CID**: `123` (queried via `IOCTL_VM_SOCKETS_GET_LOCAL_CID`).
   
   #### Ingress Walkthrough: Host SSH Connection into Devbox
   On the host, the orchestrator connects to the guest using a Unix domain socket mapped by Firecracker:
   ```bash
   # On the host: Firecracker exposes guest VSOCK as a Unix domain socket
   # Connects to Guest CID 123, Port 22 (SSH)
   socat - UNIX-CONNECT:/tmp/firecracker-vsock.sock
   ```
   Inside the guest, `devbox-ssh-over-vsock.service` is actively listening:
   ```ini
   # /etc/systemd/system/devbox-ssh-over-vsock.service
   [Unit]
   Description=Devbox SSH over VSOCK Proxy
   After=sshd.service

   [Service]
   Type=simple
   ExecStart=/usr/bin/socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```
   `socat` accepts the raw VSOCK connection and hands it off to `sshd` on localhost (`127.0.0.1:22`), logging in as user `swebot` (`sshd: swebot@notty`).
   
   *Forward-Looking Architectural Note*: In Ubuntu 24.04, guest systemd is version 255. In newer distributions (Ubuntu 24.10+ shipping systemd 256+), systemd provides native `systemd-ssh-generator(8)` and socket activation over AF_VSOCK (`ListenStream=vsock:22`). This eliminates the need for an external `socat` forwarding process by binding VSOCK sockets directly to `sshd.socket`. Google opted for the `socat` bridge pattern as a universally portable mechanism across older systemd baselines.

   #### Egress Walkthrough: Guest Python Script Talking to Host VMM
   A script running inside the guest devbox can communicate directly with the host hypervisor (CID 2):
   ```python
   import socket

   # AF_VSOCK constant = 40
   AF_VSOCK = 40
   HOST_CID = 2     # Host hypervisor
   VMM_PORT = 9999  # vmm.notify_socket

   sock = socket.socket(AF_VSOCK, socket.SOCK_STREAM)
   try:
       sock.connect((HOST_CID, VMM_PORT))
       # Send lifecycle or status heartbeat
       sock.sendall(b"READY=1\nSTATUS=Initialization complete\n")
   finally:
       sock.close()
   ```

2. **File-Piped Execution Harness via Headless Tmux & Inotifywait**:
   To execute shell commands across agent turns without spawning fresh interactive SSH logins or allocating pseudo-terminals each time, the host maintains a persistent headless `tmux` session (`default`) rooted in `/app`:
   
   #### Step 1: Host Writes Instruction Script
   The host SSH worker session writes the turn payload directly into `/run/devbox-session/default/command`:
   ```bash
   cat << 'EOF' > /run/devbox-session/default/command
   go test ./...
   EOF
   ```

   #### Step 2: Command Sourced Inside Persistent Tmux Session
   The pre-existing shell running inside tmux executes:
   ```bash
   PROMPT_COMMAND='__CODExx__=$?; echo $__CODExx__ > /run/devbox-session/default/exit_code && touch /run/devbox-session/default/stamp; unset PROMPT_COMMAND;'
   source /run/devbox-session/default/command < /run/devbox-session/default/stdin > /run/devbox-session/default/stdout 2> /run/devbox-session/default/stderr
   ```

   #### Step 3: Instant Completion Notification
   On the host SSH worker thread, an asynchronous watcher process is blocking on the directory:
   ```bash
   inotifywait -e create,moved_to --include '/stamp$' /run/devbox-session/default
   ```
   The moment `touch stamp` occurs, `inotifywait` unblocks immediately, and the host collects `exit_code`, `stdout`, and `stderr` without polling delays. The host harness maintains this loop via a co-process:
   ```bash
   coproc inw { inotifywait -e create,moved_to --include '/stamp$' /run/devbox-session/default; }
   tail --pid <PANE_PID> -f /dev/null
   ```

3. **Systemd Memory Optimization (`var-lib-systemd.mount`)**:
   Systemd state is isolated to a 4 GiB `tmpfs` at `/var/lib/systemd` (`var-lib-systemd.mount`). This completely prevents journal churn and transient unit status files from committing disk writes to the underlying ext4 overlay upperdir (`/dev/vdb`), maximizing disk throughput and prolonging flash longevity.

---

### Layer 4: Networking & Transparent Git Reverse Proxy

Networking bypasses conventional dynamic DHCP configuration:

1. **Static Boot Routing**:
   * Initialized directly from the kernel command line: `ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off`.
   * Guest IP: `192.168.0.2` on Virtio-Net (`eth0`).
   * Host Gateway: `192.168.0.1`.
2. **Transparent Git Reverse Proxy Communication (`eth0` ↔ `192.168.0.1:8080`)**:
   When a `git push`, `git fetch`, or `git clone` runs inside the devbox, traffic does not go directly to `github.com`. Instead, it talks transparently to the host reverse proxy:

   #### Step 1: Guest Initiates Request
   During initial task repository provisioning (`setup_git_config`), global Git configuration intercepts calls to GitHub:
   ```bash
   git config --global --add url.http://git@192.168.0.1:8080/.insteadOf https://github.com/
   git config --global --add url.http://git@192.168.0.1:8080/.insteadOf git@github.com:
   git config --global core.hooksPath /dev/null
   ```
   When `git clone ... /app` runs under these rules, Git evaluates `insteadOf` and permanently records the resolved proxy endpoint directly into `/app/.git/config` (`[remote "origin"] url = http://git@192.168.0.1:8080/...`).
   Immediately after the clone succeeds, the host orchestrator executes `cleanup_git_config` (`git config --global --remove url.http://git@192.168.0.1:8080/`), stripping the global rewrite rule. This ensures secondary remotes or user-specified URLs are not accidentally redirected, while all operations within `/app` continue to communicate transparently with the host proxy.

   When git executes:
   ```bash
   git fetch origin
   ```

   #### Step 2: HTTP Exchange Across the Virtual TAP Link
   The guest makes a standard HTTP request across `eth0` to the host gateway:
   ```http
   POST /sys-dissect/google-jules-sandbox-architecture.git/git-upload-pack HTTP/1.1
   Host: 192.168.0.1:8080
   User-Agent: git/2.43.0
   Accept-Encoding: gzip
   Content-Type: application/x-git-upload-pack-request

   0014command=fetch
   ...
   ```

   #### Step 3: Host Side Injects OAuth Token and Proxies Upstream
   The host gateway HTTP daemon (`Server: BaseHTTP/0.6 Python/3.12.3`) intercepts the request:
   ```python
   # Conceptual representation of host proxy logic
   class GitProxyHandler(BaseHTTPRequestHandler):
       def do_POST(self):
           # 1. Intercept destination repo from self.path
           target = "https://github.com" + self.path
           
           # 2. Inject ephemeral GitHub App / OAuth token
           headers = dict(self.headers)
           headers["Authorization"] = f"Bearer {ephemeral_github_token}"
           
           # 3. Forward upstream to github.com and stream response back to guest
           upstream_req = urllib.request.Request(target, data=body, headers=headers)
           ...
   ```
   
   #### Security & Threat Model Properties:
   * **Zero Token In-Guest Footprint**: The guest environment never sees or stores GitHub OAuth secrets or personal access tokens; credentials exist exclusively in the host process memory.
   * **Hook Execution Prevention**: The global Git config enforces `core.hooksPath /dev/null`, preventing a cloned repository from abusing git hooks (`pre-commit`, `post-checkout`) to execute covert payloads outside the observable execution harness.
   * **Branch Confinement**: Push operations are validated at the proxy, preventing unexpected modifications outside authorized task branches (`jules-<task_id>-<hash>`).

3. **Public Egress & NAT**:
   * Outbound TCP/UDP egress is fully permitted across all ports (80, 443, 8080, 22, etc.).
   * Public egress NAT resolves to Google Cloud Platform (`us-central1`).
   * Virtual network devices (`/dev/net/tun`) are available for user-space VPN tunnels.

---

### Layer 5: Security Model & Runtime Confinement

Google Jules implements a **Hardware-Boundary Security Model**:

* **Guest Privilege Model**:
  * Primary user: `jules` (UID 1001, GID 1001).
  * Passwordless `sudo` (`jules ALL=(ALL) NOPASSWD:ALL`).
  * Unrestricted access to kernel sysctls, network configuration, and root filesystems.
* **Kernel Syscall Hardening Profile**:
  * **Complete Omission of Kernel Seccomp**: Kernel configuration forensics (`evidence/live_telemetry_antigravity/kernel_and_hypervisor/kernel_security_config.txt`) prove that `# CONFIG_SECCOMP is not set`. The guest kernel was compiled without seccomp subsystem support; `/proc/self/status` has no Seccomp field. The agent has unrestricted access to all 450+ Linux x86_64 system calls.
  * **Purely Monolithic Kernel Architecture**: `# CONFIG_MODULES is not set`. Kernel module loading is completely disabled (`/proc/modules` is empty and `lsmod` exits cleanly with zero output). No rootkit or rogue kernel driver can be loaded into ring 0.
  * **Absence of In-Guest Linux Security Modules (LSM)**: `# CONFIG_SECURITY is not set` and `# CONFIG_SECURITYFS is not set`. AppArmor, SELinux, Landlock, and Smack are absent.
  * **eBPF Restrictions**: While `CONFIG_BPF=y` and `CONFIG_BPF_SYSCALL=y` are present, `unprivileged_bpf_disabled` is set to `2` (permanently locked off). Direct `bpf(2)` syscall invocation returns `-1` (EPERM), preventing unprivileged kernel tracing or ring 0 inspection.
* **Unthrottled Cgroups v2 Resource Hierarchy**:
  * The unified cgroup tree at `/sys/fs/cgroup/` imposes zero bandwidth caps:
    * `user.slice`: `memory.max = max`, `cpu.max = max 100000` (unlimited).
    * `system.slice`: `memory.max = max`, `cpu.max = max 100000` (unlimited).
  * Google delegates 100% of resource quotas, burst control, and OOM handling to the host Firecracker cgroup boundary.
* **Memory & Hardware Boundary Guarantees**:
  * 8 GiB RAM, zero swap, Transparent Huge Pages in `[madvise]` mode, and KSM disabled (`run = 0`) to prevent host-level memory deduplication side-channels.
  * 4 physical vCPUs without SMT (`smt=false`), eliminating hyper-threading side-channel leakage.
* **Confinement Philosophy**:
  * Instead of attempting to trap or restrict dangerous syscalls inside the guest (which degrades tool compatibility and developer productivity), Google places 100% of the security trust in the **KVM / Firecracker hypervisor hardware boundary**.
  * Any guest kernel compromise or privilege escalation is contained strictly within the microVM boundary. Escape requires a full KVM or Firecracker hypervisor exploit.

---

## 2. Master Mermaid Topology Diagrams

### Diagram 1: Full System Topology & Bus Mapping

```mermaid
graph TB
    subgraph Host["Host Machine (GCP Bare-Metal / KVM Host)"]
        subgraph VMM["AWS Firecracker MicroVM Process"]
            ACPI["ACPI Tables<br/>FIRECK / FCAT 20240119"]
            vCPU["4x vCPUs (Intel Xeon Processor @ 2.30GHz)"]
            RAM["8 GiB Physical RAM (TSC Clock)"]

            subgraph MMIO["Virtio-MMIO Bus (pci=off)"]
                M1["0xc0001000: virtio0 (Block)"]
                M2["0xc0002000: virtio1 (Block)"]
                M3["0xc0003000: virtio2 (Net)"]
                M4["0xc0004000: virtio3 (VSOCK)"]
            end
        end

        GW["devbox-gateway.internal (192.168.0.1)<br/>DNS: Port 53 | Git Proxy: Port 8080"]
        VMM_SOCKET["vmm.notify_socket<br/>VSOCK Stream 2:9999"]
    end

    subgraph Guest["Guest MicroVM Devbox (Linux 6.8.0-devbox)"]
        subgraph Disks["Block Devices"]
            VDA["/dev/vda: 4.36 GiB SquashFS 4.0 (/rom)"]
            VDB["/dev/vdb: 100 GiB ext4 Scratch (/rom/overlay)"]
        end

        subgraph Overlay["Filesystem Root (pivot_root)"]
            ROOTFS["OverlayFS: /<br/>lower=/rom, upper=/overlay/root, work=/overlay/work"]
            SYS_TMP["/var/lib/systemd (4 GiB tmpfs)"]
        end

        subgraph Networking["Network Stack"]
            ETH0["eth0: 192.168.0.2/24<br/>Static Kernel Config"]
        end

        subgraph IPC["Control & IPC Plane"]
            SOCAT["socat Forwarder (PID 876)<br/>VSOCK-LISTEN:22 -> TCP:127.0.0.1:22"]
            SSHD["sshd: swebot@notty (PID 929)"]
            TMUX["tmux 'default' (PID 2348)<br/>/run/devbox-session/default/"]
            INOTIFY["inotifywait watcher (stamp)"]
        end
    end

    %% Bus connections
    M1 --- VDA
    M2 --- VDB
    M3 --- ETH0
    M4 --- SOCAT

    %% Storage initialization
    VDA --> ROOTFS
    VDB --> ROOTFS

    %% Network traffic
    ETH0 --> GW
    SOCAT --> SSHD --> TMUX --> INOTIFY
    IPC -.->|Notify| VMM_SOCKET
```

---

### Diagram 2: Request & Task Execution Flow

```mermaid
sequenceDiagram
    autonumber
    participant Dev as GitHub User / Issue
    participant Orch as Jules Orchestration Cloud
    participant VMM as Firecracker MicroVM (Host CID 2)
    participant VSOCK as VSOCK Bridge (Guest CID 123)
    participant Tmux as Tmux Harness (/run/devbox-session)
    participant Proxy as Git Proxy (192.168.0.1:8080)
    participant GH as GitHub API / Repo

    Dev->>Orch: Trigger Task (@jules mention / issue)
    Orch->>VMM: Warm Resume MicroVM & Clock Resync
    VMM->>VSOCK: Connect over AF_VSOCK (socat -> sshd)
    VSOCK->>Tmux: Initialize Headless Session 'default'
    Orch->>Proxy: Provision Ephemeral OAuth Credentials
    Tmux->>Proxy: git clone (rewritten via insteadOf)
    Proxy->>GH: Forward Clone Request with Auth Headers
    GH-->>Tmux: Clone Target Repo to /app

    loop Agent Reasoning & Execution Turns
        Orch->>Tmux: Stage Command in /run/devbox-session/default/command
        Tmux->>Tmux: Execute Command with PROMPT_COMMAND exit-code trap
        Tmux->>Tmux: echo $? > exit_code && touch stamp
        Tmux-->>Orch: inotifywait catches stamp, harvests stdout/stderr/diff
        Orch->>VMM: Suspend vCPUs (crng reseed on resume)
    end

    Orch->>Tmux: git push origin jules-<task_id>-<hash>
    Tmux->>Proxy: Push Commits
    Proxy->>GH: Authenticated Commit Push
    Orch->>Dev: Open Pull Request with Architectural Summary
```

---

### Diagram 3: Boot & Storage Pivot Flow

```mermaid
flowchart TD
    A[Firecracker Ingress: Kernel Boot] --> B[pci=off & Virtio-MMIO Resource Binding]
    B --> C[Kernel loads /dev/vda as root ro]
    C --> D[Kernel executes init=/usr/sbin/overlay-init]

    subgraph OverlayInit["/usr/sbin/overlay-init Execution"]
        E["mount /dev/vdb /overlay"]
        F["mkdir -p /overlay/root /overlay/work /overlay/root/rom"]
        G["mount -t overlay -o noatime,lowerdir=/,upperdir=/overlay/root,workdir=/overlay/work overlayfs /merged"]
        H["pivot_root /merged /merged/rom"]
        I["rmdir /overlay /merged"]
        J["exec /usr/sbin/init (systemd)"]

        E --> F --> G --> H --> I --> J
    end

    D --> OverlayInit
    J --> K[Systemd PID 1 Starts]
    K --> L["Mount /var/lib/systemd as tmpfs (4 GiB)"]
    K --> M[devbox-ssh-over-vsock.service starts socat]
    K --> N[sshd listens on 127.0.0.1:22]
    K --> O[System Ready for Host Orchestration]
```

---

## 3. Comparative Matrix: Google Jules vs. Gemini Spark

The following matrix compares Google's two primary agent execution paradigms:

| Architectural Dimension | Google Jules Devbox | Gemini Spark Sandbox |
| :--- | :--- | :--- |
| **Virtualization Primitive** | Hardware Virtual Machine (**Linux KVM**) | Syscall Emulation Process Boundary (**gVisor / Sentry**) |
| **Hypervisor Engine** | **AWS Firecracker** (ACPI `FIRECK` / `FCAT 20240119`) | gVisor Gofer + Sentry (Linux 4.19 ABI) |
| **Bus Topography** | **`pci=off`** with Virtio-MMIO (`0xc0001000`–`0xc0004000`) | Synthetic Gofer VFS / Plan 9 host mounts |
| **Guest Privilege Model** | Primary user `jules` (UID 1001) with **passwordless `sudo`** | Unprivileged `spark` (UID 1235), `CapEff: 0x0`, zero root |
| **Security Enforcement** | **Hardware Boundary Isolation** (No in-guest LSM / Seccomp) | **Syscall Filter Confinement** (Strict seccomp sandbox) |
| **Outbound Network Access** | **Unrestricted Public Egress** (HTTPS, UDP, DNS, high ports) | **Strict Air-Gap** (Loopback only, zero outbound routes) |
| **Host-to-Guest Control Plane**| **AF_VSOCK** (Host CID 2, Guest CID 123) + `socat` SSH | `runsc exec` + Unix domain sockets (`/ipc/remy_memfs_proxy.sock`) |
| **Execution Supervisor** | Headless **`tmux`** session + file FIFO (`devbox-session`) | In-memory **FastAPI / Uvicorn** supervisor (`dynamo_exec.py`) |
| **Root Filesystem** | Dual-Disk: Read-only **SquashFS 4.0** + 100 GiB **ext4** overlay | Synthetic root tmpfs + Plan 9 (9P) persistent host mounts |
| **Durability Lifecycle** | Intra-task durable ext4 upperdir; cross-task snapshot clone | Ephemeral turn container; memory state synced to host Remy |
| **Container Engine** | `dockerd` active (default overlay-on-overlay fails; VFS succeeds) | Container engines completely disallowed inside gVisor |
| **Browser Automation Engine** | Native **Google Chrome** (268 MB) + **Playwright** virtualenv | Headless 1440p TigerVNC virtual display + `ffmpeg` + `xdotool` |
| **External Ingress Support** | User-space **Tailcat WireGuard** relay tunnel | No ingress permitted |

---

## Conclusion & Legacy

Google Jules represents an architectural triumph of **pragmatic systems design over synthetic containment**. Rather than expending engineering effort building bespoke syscall emulation layers, restricted chroots, or fragile container isolation harnesses, Google leveraged battle-tested virtualization primitives: AWS Firecracker microVMs, Linux KVM, Virtio-MMIO, and standard Unix tooling (`tmux`, `socat`, `sshd`, `inotifywait`).

This architecture granted the agent unrestricted superuser flexibility—enabling compilation of complex C/C++ trees, headless browser rendering, full package management, and custom daemon execution—while guaranteeing enterprise-grade workload isolation strictly at the hardware virtualization boundary.
