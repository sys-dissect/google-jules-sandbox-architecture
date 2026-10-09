# Incremental Sandbox Telemetry & Platform Deep-Dive Audit

## Executive Summary

This report extends the empirical systems dissection of Google's **Jules** devbox platform by capturing granular isolation, kernel capability posture, network perimeter reachability, privileged binaries, and early orchestration lifecycle events.

---

## 1. Kernel Security & Isolation Matrix

* **Seccomp Subsystem**:
  - `Seccomp: 0` (Disabled across PID 1 init process and current user shell sessions). System calls are not filtered by a guest Seccomp BPF profile.
* **Linux Capabilities**:
  - Full effective and bounding capability set granted to root (`CapInh: 0000000000000000`, `CapPrm: 000001ffffffffff`, `CapEff: 000001ffffffffff`, `CapBnd: 000001ffffffffff`, `CapAmb: 0000000000000000`).
* **CPU Hardware Vulnerability Mitigations**:
  - All standard kernel mitigation flags active (`itlb_multihit`, `l1tf`, `mdb`, `meltdown`, `spec_store_bypass`, `spectre_v1`, `spectre_v2`, `srbds`, `tsx_async_abort`).
  - **SMT / Hyperthreading**: SMT Host state is unknown (hypervisor abstracts topology; l1tf: PTE Inversion active).

---

## 2. Network & Cloud Perimeter

* **Cloud Metadata Endpoints (169.254.169.254 / metadata.google.internal)**:
  - All HTTP probes to AWS/GCP link-local metadata endpoints (`169.254.169.254` and `metadata.google.internal`) time out with zero connection response. No cloud metadata service is exposed to the guest microVM.
* **Subnet Sweep (`192.168.0.0/24`)**:
  - `192.168.0.1:8080`: **OPEN** (Firecracker host gateway proxy service).
  - `192.168.0.2:22`: **OPEN** (Guest local loopback/eth0 SSH listener interface).
  - `192.168.0.3`, `192.168.0.4`, `192.168.0.254`: Unresponsive.
* **DNS Resolution**:
  - `/etc/resolv.conf` statically points to `nameserver 192.168.0.1` (the host gateway proxy). systemd-resolved (`resolvectl`) is absent/disabled.

---

## 3. Internal Privilege Footprint & Background Tasks

* **SUID / SGID Binaries**:
  - `/opt/google/chrome/chrome-sandbox`: SUID root binary used by Google Chrome for browser process isolation.
  - Standard Ubuntu privilege binaries present (`sudo`, `passwd`, `su`, `mount`, `umount`, `gpasswd`, `ssh-agent`, `ssh-keysign`).
* **Cron & Systemd Timers**:
  - User crontab (`crontab`) is absent.
  - Active systemd timers: `sysstat-collect.timer`, `fstrim.timer`, `phpsessionclean.timer`, `motd-news.timer`, `dpkg-db-backup.timer`, `apt-daily.timer`, `e2scrub_all.timer`.

---

## 4. Hypervisor, DMI & Observability Footprint

* **DMI / SMBIOS Tables**:
  - `/sys/class/dmi/id/*` is unpopulated; kernel log confirms `DMI not present or invalid.` (characteristic of lightweight AWS Firecracker microVMs).
* **eBPF & Kernel Tracing**:
  - `/sys/kernel/debug/tracing` is inaccessible/unmounted.
  - `/sys/fs/bpf` contains standard bpf filesystem state, but no active eBPF programs or maps are loaded by default (`bpftool` not installed).
* **Entropy Source**:
  - `/proc/sys/kernel/random/entropy_avail`: `256`.
  - `/sys/class/misc/hw_random/rng_current`: `none` (CRNG initialized at boot via kernel command line/virtio-rng seed).

---

## 5. Comprehensive Package Inventory Summary

* **Manifest Statistics**:
  - Total Debian/Ubuntu packages installed (`dpkg-query`): **1,228 packages**.
* **Key Development & System Tooling**:
  - Development tools: `clang`, `gcc`, `cmake`, `ninja-build`, `git`, `bind9-dnsutils`, `curl`, `jq`, `ripgrep`, `tmux`, `socat`.
  - Runtimes: `aspnetcore-runtime-8.0`, `aspnetcore-runtime-10.0`, `java-21-openjdk`, `python3.12`, `google-chrome-stable`.

---

## 6. System Initialization & `swebot` Harness Lifecycle

* **Startup Timestamp**:
  - Initial user session startup logged at `17:10:38 devbox systemd[887]`. User target initialization completed in `613ms`.
* **Harness Setup Invocations**:
  - Early boot harness setup command executed via sudo:
    ```bash
    sudo /usr/bin/bash -c 'echo "${BASHPID}"; set -xe; echo nameserver 192.168.0.1 > /etc/resolv.conf; timeout 1s socat /dev/null TCP4:devbox-gateway.internal:53'
    ```
