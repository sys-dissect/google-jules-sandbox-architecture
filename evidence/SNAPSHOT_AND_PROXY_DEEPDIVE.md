# Phase 2 Deep-Dive — Snapshot Architecture, Git Proxy, & Init Internals

## Executive Summary

Following up on initial telemetry observations (`crng reseeded due to virtual machine fork` and local proxy `192.168.0.1:8080`), this Phase 2 root-level audit dissects the Firecracker snapshot restoration mechanisms, host Git proxy headers, custom `/usr/sbin/overlay-init` script, and privileged root security boundaries.

---

## 1. VM Snapshot Fork & Clock Topology

* **Clocksource & Time Synchronization**:
  - Current clocksource: `tsc` (available clocksources: `tsc`, `acpi_pm`).
  - `timedatectl timesync-status`: systemd-timesyncd is not running (`org.freedesktop.timesync1` absent).
* **Uptime Reconciliation**:
  - System `uptime`: `10:37:05 up 56 min, load average: 0.22, 0.24, 0.15`.
  - `/proc/uptime`: `3403.71 13002.78` (~56 minutes of active running time).
  - **Snapshot Restoration Mechanics**: Upon turn startup, the Firecracker microVM is resumed from a warm snapshot. Firecracker re-initializes kernel randomness via `random: crng reseeded due to virtual machine fork` and resynchronizes the guest clock via hypervisor TSC scaling rather than NTP network polling.

---

## 2. Git Proxy & Network Perimeter Dissection

* **Proxy Probe (`http://192.168.0.1:8080/`)**:
  - **Server Signature**: `Server: BaseHTTP/0.6 Python/3.12.3` wrapping upstream `Server: github.com`.
  - **Health Endpoint (`/healthz`)**: Returns `200 OK` with `Service ready.`.
  - **Headers**: Includes GitHub request IDs (`X-GitHub-Request-Id: 95F1:2993EA...`), session cookies (`_gh_sess`), and edge region metadata (`x-github-edge-region: iad`).
* **Outbound HTTPS Egress**:
  - Direct HTTPS probes to public internet endpoints (e.g. `curl -I https://www.google.com`) return standard `HTTP/2 200` responses directly, confirming outbound HTTPS egress is permitted without mandatory interception.
* **Custom CA Certificates**:
  - `/usr/local/share/ca-certificates/` is empty; the proxy relies on standard system CA bundles.

---

## 3. The `/usr/sbin/overlay-init` Implementation

The kernel command line specifies `init=/usr/sbin/overlay-init`. The actual shell script source code (`/usr/sbin/overlay-init`) operates as follows:

```sh
#!/bin/sh

ls /dev/disk/by-label
/bin/mount /dev/vdb /overlay

mkdir -p /overlay/root /overlay/work /overlay/root/rom

/bin/mount \
    -o noatime,lowerdir=/,upperdir=/overlay/root,workdir=/overlay/work \
    -t overlay "overlayfs:/overlay/root" /merged

/usr/sbin/pivot_root /merged /merged/rom

# remove dirs for setting up the overlay from the new root
rmdir /overlay
rmdir /merged
```

### Architectural Breakdown:
1. Mounts read-write ext4 scratch disk `/dev/vdb` at `/overlay`.
2. Creates `/overlay/root` (upperdir) and `/overlay/work` (workdir).
3. Constructs an `overlayfs` stack combining lower read-only SquashFS root `/` with upper writable `/overlay/root`.
4. Executes `pivot_root /merged /merged/rom` to make the combined overlay the new filesystem root `/`, pushing the base image to `/rom`.
5. Hands over execution to real systemd init (`/usr/sbin/init`).

---

## 4. Privileged Security Boundary & Firewall Rules

* **AppArmor & LSM Status**:
  - `/sys/kernel/security/lsm` is absent; AppArmor is not active inside the guest microVM (`aa-status` not running).
* **eBPF Mount**:
  - `/sys/fs/bpf` directory is mounted with permissions `drwx-----T root root`, but no active eBPF programs or maps are loaded by the host into the guest.
* **Guest Firewall Rules (`iptables` & `nftables`)**:
  - `iptables`: Default policy `INPUT ACCEPT`, `FORWARD DROP`, `OUTPUT ACCEPT`. Contains standard Docker bridge chains (`DOCKER`, `DOCKER-FORWARD`, `DOCKER-USER`).
  - `nftables`: Managed via `iptables-nft` translation layer; includes masquerade rules for `docker0` bridge network (`172.17.0.0/16`).
