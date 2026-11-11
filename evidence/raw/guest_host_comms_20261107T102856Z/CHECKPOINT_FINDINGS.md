# Extraction Checkpoint — Guest/Host + Golden Image

Captured: 2026-11-07 ~10:46 UTC. VM scheduled for destruction ~2026-11-11.
All work saved here so a VM freeze does not lose it.

## Repo/persistence constraints
- The GitHub repo is **public** (`HTTP 200` unauthenticated). Secret material (private
  keys, tokens) is therefore kept **out** of the repo.
- Private/live content-bearing captures are in `/home/jules/ghc_private/` (0700),
  including `session_events.log`, copied `command/stdin/stdout/stderr`, and
  `journal_harness.log`.
- Push from the guest is blocked: direct HTTPS push needs a username; the `:8080`
  reverse proxy returns `401 No anonymous write access` for `git-receive-pack`.

## Golden image provenance (new)
- `/etc/devbox-version-info` → `rootfs-20260306-162806.img`
- `/etc/devbox-rebuild-hash` → `202610`
- `/etc/machine-id` → `58bffcf38f8d4939bd3e07b2ea187369`
- Rootfs assembled **2026-03-06**; base debootstrap **2026-02-10** from
  `ftpmaster.internal` (see `golden/bootstrap.log`).
- APT mirror: `http://us-central1.gce.archive.ubuntu.com/ubuntu/`.
- Filesystem timeline: vda SquashFS created epoch 0; vdb ext4 created 2026-03-06 17:10:25.

## High-value findings so far
1. **Baked SSH host private keys.** `/rom/etc/ssh/ssh_host_{rsa,ecdsa,ed25519}_key`
   are byte-identical to the live `/etc/ssh/*` (sha256 in `golden/golden_inventory.txt`).
   Every devbox cloned from this image shares the same SSH host private keys.
   (Key material intentionally not copied into the public repo; fingerprints only.)
2. **Baked Android ADB private key** at `/rom/root/.android/adbkey` (hash recorded).
3. **No bash/tool history baked** into `/rom/root` or `/rom/home/*` (globs empty).
4. **Custom units baked:** `devbox-ssh-over-vsock.service`, `var-lib-systemd.mount`,
   `sshd.service` (overrides stock). Full text in `golden/golden_inventory.txt`.
5. **Control plane is TCP over virtio-net, not VSOCK** (see `../../GUEST_HOST_COMMS.md`):
   `swebot` SSH sessions arrive from `192.168.0.1` to `192.168.0.2:22`; the VSOCK
   bridge is idle; CID 2:9999 resets.
6. **`swebot` is UID 1001 = `jules`**, `/home/swebot -> /home/jules`; same RSA
   authorized key is also in `/root/.ssh/authorized_keys`; `PermitRootLogin without-password`.
7. Host-side harness runs `git add -A` + `git diff --minimal --binary -U3 <base>`
   roughly every 2 s over the swebot SSH session (workspace diff streaming).

## Artifacts in this directory
- `golden/golden_inventory.txt` — full golden-image inventory (logs, units, keys, sources, shadow state).
- `golden/bootstrap.log` — debootstrap build log (61 KB, Feb 10 2026).
- `golden/apt_history.log` (111 KB), `golden/apt_term.log` (451 KB), `golden/dpkg.log` (1.1 MB).
- `golden/devbox-version-info`, `golden/devbox-rebuild-hash`.
- `host_scan/`, `vsock/`, `live/`, `system/`, `secrets/` — filled in subsequent checkpoints.

## Golden image build chain (refined)
- Base: Ubuntu **OCI-minimized** image — `/etc/cloud/build.info`:
  `build_name: ubuntu-oci:minimized`, `serial: 20260210.1` (copy in `golden/cloud-build.info`).
- Debootstrap/provisioning: **2026-02-10 14:05** via `ftpmaster.internal`.
- Toolchain provisioning: **2026-03-02 16:32–16:40** (apt history). Chrome
  `145.0.7632.116` installed from `/tmp/chrome.deb`; Docker CE replaces
  `docker.io`/`containerd`/`runc`; `git` upgraded to `2.53.0` from the git-core PPA.
- Final touch: `libnss3` security upgrade **2026-03-06 16:39**, apt log
  `Requested-By: jules (1001)` — the image was finalized under the `jules` account.
- Rootfs artifact name `rootfs-20260306-162806.img`; vdb ext4 created
  **2026-03-06 17:10:25**; first devbox boot **17:10:29**.
- **No** cloud/GitHub/Docker credentials baked. Only private key material present:
  the shared SSH host keys and `/root/.android/adbkey`.
- `/usr/local`: Go 1.24 toolchain, Bun, Composer, Bundler.
- `/root` home is minimal: no `.bash_history`, no gcloud/aws/docker config.

## Host gateway `192.168.0.1` — service surface
- **TCP:** only `53` and `8080` (dnsmasq + Python reverse proxy). Full 1–65535 sweep
  found `53`; `8080` was missed under a 65k-SYN burst but confirmed by sequential
  connect and a narrow rescan — the single-threaded Python proxy drops connection
  bursts (a robustness/DoS note, it recovered immediately).
- **UDP:** only `53/udp` confirmed open. `67/68,111,162,500,1900,5353` are
  `open|filtered` (no response), not confirmed.
- **DNS fingerprint:** `version.bind CH TXT` → `"dnsmasq-2.91"`.
- **OS/TTL:** ICMP TTL 64 (Linux); 0.4 ms RTT.
- **Host tap MAC:** observed `9a:d0:40:b6:36:f0` at 09:42 UTC and
  `42:d0:d9:5b:d3:31` at 10:51 UTC — the gateway L2 identity is **not stable**
  across time (tap re-created / randomized).
- **Proxy method matrix:** `GET`/`POST` → 200; `PUT/DELETE/OPTIONS/HEAD/PATCH` → 501.
- **Proxy path matrix:** only `/healthz` is served locally (`200`); `/readyz`,
  `/livez`, `/metrics`, `/debug`, `/status`, `/robots.txt` are all **proxied to
  GitHub** (they return `Server: github.com`). `/version` → 404, `/api` → 404,
  `/openapi.json` → 410 (also from GitHub).

## VSOCK — definitive runtime result
- Full `CID 2` sweep, ports `1–65535`: **0 open**.
- `CID 0` (hypervisor), ports `1–65535`: **0 open**.
- `CID 1` (local): port `22` open (the `socat` loopback listener).
- Therefore the `vmm.notify_socket:vsock-stream:2:9999` endpoint is **not listening**
  in this resumed VM; there are **no reachable guest→host VSOCK services**.

## Pending
- Refined secret sweep (excluding vendored libs) + cloud/gcloud/docker config dirs.
- Full TCP/UDP scan of host gateway `192.168.0.1`; DNS fingerprint; `:8080` method/path matrix.
- Full VSOCK CID 0/1/2 port sweep.
- Persistent live harness telemetry (systemd --user transient unit) + session captures.
- System provenance snapshot (dpkg, units, sysctl, dmesg, journal size).
- Final write-up + commit.

## Credential findings (2026-11-07, values withheld from this public repo)
- **`jules` has a baked, non-locked yescrypt password.** Offline check matched a
  trivial default (value withheld). `sshd -T` reports `passwordauthentication yes`,
  and `jules` has `NOPASSWD: ALL` sudo — so password login → root. This hash is
  baked into `/rom/etc/shadow`, i.e. **shared by every clone** of the image.
- `root`, `ubuntu`, `swebot` are locked; only `jules` is unlocked.
- The live agent setup added `GOEDEL_API_KEY` to `/home/jules/.bashrc` and
  `/home/jules/.profile`, and `TAILCAT_PEER_KEY` is in the `opencode` process env.
  These are **not** baked into the image and are **not** committed here.
- Tailcat is `v0.7.0`; DERP map cached; live relay is region `301` (NYC,
  `199.38.181.166`) — matches `TAILCAT_SSH.md`.
- OpenCode model: `goedelmachines/deepseek-v4.1-flash` (`live/opencode_model.json`).
- Playwright installed via `pipx install playwright` on 2026-03-02 16:40:03
  (`golden/golden_extras.txt`).
- No cloud-init seed/user-data, no `docker/daemon.json`; `/opt/jules` holds the
  pipx/Playwright venvs.

## Cross-verification against the published repo (2026-11-07)
- **Kernel config:** live `/proc/config.gz` vs repo `raw_telemetry/final_pass/kernel_config.txt` → **0 diff lines**.
- **Kernel cmdline:** SHA256 `4cb6877c…eb5d784` identical to repo `live_telemetry_antigravity/kernel_and_hypervisor/cmdline.txt`.
- **ACPI DSDT:** live table SHA256 `11577db8…95258ae` identical to the DSDT inside the repo `acpi_tables.tar.gz`.
  → This VM is the same Firecracker/kernel/golden-image lineage as the published study.
- **Clock:** guest epoch matches host HTTP `Date` within ~0–1 s (`2026-11-07T10:56:27Z`), despite the
  snapshot-resume signature (journal boot ID spans 2026-03-06 → 2026-11-07; dmesg monotonic ~245.7 days;
  `/proc/uptime` ~minutes). The guest wall clock is resynced at resume.
- **Host DNS internal names:** `devbox-gateway.internal → 192.168.0.1`;
  `metadata.goog → 169.254.169.254` (resolves, but direct metadata HTTP is blocked);
  `metadata.google.internal` / `ftpmaster.internal` → no answer.
- **Tailcat host key is ephemeral:** `~/.config/tailcat/ssh/ssh_host_ed25519_key` created 09:07:15,
  per session; the node/peer key is injected via `TAILCAT_PEER_KEY`.
- **Journal timeline** (entries per 10-min bucket): `2026-03-06T17:10` = 536 (original boot),
  then `2026-11-07` 09:00→10:50 with spikes at 09:50 and 10:40 (evidence/extraction activity).

## VM Generation ID / snapshot-fork mechanism (new)
- ACPI `FCVMGID:00` at `\_SB.VGEN`, `_HID=FCVMGID`, `_CID/_DDN=VM_Gen_Counter`;
  Linux binds driver `vmgenid`; `CONFIG_VMGENID=y`; shares ACPI GED IRQ 9.
- dmesg shows 5× `random: crng reseeded due to virtual machine fork` — the driver
  detects each Firecracker snapshot fork and reseeds the CRNG.
- This is the concrete mechanism behind boot_id persistence, the Mar-6→Nov-7 journal
  span, the uptime/dmesg-monotonic divergence, and clock resync.
- Cloud metadata: `metadata.goog` resolves to 169.254.169.254 via dnsmasq, route
  goes via 192.168.0.1, but every metadata endpoint (GCP v1, AWS IMDSv1/v2, IPv6
  fd20:ce::254) is unreachable (connect refused). No explicit iptables 169.254 rule.
- swebot/sshd session environments are empty; orchestration is command/file-driven.
- New doc: `evidence/VMGENID_AND_SNAPSHOT_FORK.md`.

## Boot timing, auth surface, agent plane (new)
- **Boot:** `systemd-analyze` = 3.049 s kernel + 18.167 s userspace = **21.217 s** to
  `graphical.target`; `sshd` listening ≈7 s after kernel start; `docker.service` 7.53 s,
  `containerd` 2.84 s, `ldconfig` 5.92 s. The "sub-second boot" claim is corrected in
  README/ARCHITECTURE.
- **Auth:** `passwordauthentication yes`, `permitrootlogin without-password`,
  socket-activated `ssh.socket`, `allowtcpforwarding yes`, `maxsessions 10`. Combined with
  `jules`'s baked weak password + `NOPASSWD` sudo ⇒ password→root.
- **Agent plane:** OpenCode **1.19.5**, provider `goedelmachines`, baseURL
  `https://api.goedelmachines.com/v1`, model `deepseek-v4.1-flash`, tool permissions
  **allow-all** (`bash`, `webfetch`). API key via `GOEDEL_API_KEY` (not committed).
- **Host orchestration mix** (journal): `git add -A` ×296, `git diff --minimal --binary` ×137,
  `git show base:README.md` ×75, `--diff-filter=AM` ×27, harness staging ×54 each, and a
  loop over `README.md evidence/GUEST_HOST_COMMS.md` ×10 — the host is actively processing
  the new evidence for the host-side push.

## Egress, containers, Tailcat (new)
- Subnet 192.168.0.0/24 contains only gateway .1 and guest .2. Outbound HTTPS works
  (google 200) and outbound UDP/53 to 8.8.8.8 works; metadata endpoints are blackholed.
- Docker 29.2.1, containerd overlayfs snapshotter, namespace `moby`, 0 containers,
  1 image (alpine, from this audit). Stock containerd config (`disabled_plugins=["cri"]`).
- Tailcat **v0.7.0** (`github.com/tailscale/tailcat`, go1.27.3); invocation is
  `serve --ssh-authorized-keys=… ssh` (SSH only). No local control API. **Its stdio is
  bound to `/run/devbox-session/default/{stdin,stdout,stderr}`** — the ingress server is
  launched through the Jules harness FIFO. Per-session SSH host key; DERP region 301 NYC.
- New doc: `evidence/LIVE_RUNTIME_CONFIRMATIONS.md`.

## Live credential confirmation
- Live `/etc/shadow` jules hash == golden `/rom/etc/shadow` hash; still matches the
  trivial default; `/etc/shadow` mtime `2026-03-04 22:11:03` (never rotated).
- Live `/etc/passwd` == golden `/etc/passwd`. Weak password + `PasswordAuthentication yes`
  + `NOPASSWD` sudo is a live, fleet-wide password→root path.

## Active guest->host communication (new)
- VSOCK CID 2 closed even with `VMADDR_FLAG_TO_HOST`; only local CID 1:22 answers.
- Definitive full TCP scan of 192.168.0.1: only `53/tcp` and `8080/tcp`.
- Host DNS dnsmasq 2.91: persistent DNS-over-TCP session (3 queries, one socket);
  wildcard `*.devbox-gateway.internal -> 192.168.0.1`; version.bind answered locally;
  other types forwarded upstream.
- Host HTTP proxy: `/healthz` host-generated `Service ready.`; absolute-URI rejected
  with `400 Absolute URI with domain/scheme is not allowed`; Host ignored (path maps
  to github.com); receive-pack 401.
- ICMP custom payload echoed verbatim (MATCH) — verified L3 round-trip; ARP returns
  host MAC. DHCPDISCOVER gets no reply (DNS-only).
- No shell/command path into the host from the guest.
- New doc: `evidence/HOST_COMMS_CHANNELS.md`.

## Cross-repo probe transfer (Spark/Muse/JioPC)
- No hidden guest-agent: Unix socket matrix is standard services only; no virtio-serial/vport/hvc (only ttyS0), despite CONFIG_VIRTIO_CONSOLE=y.
- No TLS interception (real Sectigo cert, no custom CA); no RFC2544 DNS VIP (real IPs); VSOCK CID2:512 closed.
- No logind killswitch/linger (Linger=no, no logind.conf overrides).
- Security subsystem compiled out: CONFIG_SECURITY/SECURITYFS/AUDIT/SECCOMP all unset; no /proc/self/attr, no securityfs, no yama.
- Unprivileged userns enabled: `unshare -Ur` -> uid 0, can mount tmpfs and create net/pid namespaces; memfd, memfd_secret, io_uring available; userfaultfd/kexec/Landlock compiled out; unpriv BPF locked, perf paranoid=2; root full caps.
- New doc: `evidence/CROSS_REPO_PROBES.md`.
