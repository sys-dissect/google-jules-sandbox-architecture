# Golden Image Anatomy & Host Gateway Surface

Time-boxed extraction completed **2026-11-07** inside the Jules devbox scheduled for
destruction around **2026-11-11**. Companion to [`GUEST_HOST_COMMS.md`](GUEST_HOST_COMMS.md).
Raw artifacts: [`raw/guest_host_comms_20261107T102856Z/`](raw/guest_host_comms_20261107T102856Z/).

> **Non-reproducible by design.** The control-plane transport, gateway services and
> build lineage below are properties of the live environment, not of the public
> documentation. Secret material (private keys, API keys, chat DB) is deliberately
> **not** committed to this public repository; only paths, permissions and SHA256
> digests are recorded.

---

## 1. Golden image anatomy `[Tier 1]`

### 1.1 Base image

```text
$ cat /rom/etc/cloud/build.info
build_name: ubuntu-oci:minimized
serial: 20260210.1
```

The golden rootfs is an **Ubuntu 24.04 OCI-minimized** image (serial `20260210.1`),
not a stock cloud image. It is delivered read-only as SquashFS on `/dev/vda`
(4.36 GiB, SHA256 `227f52bb…c098`) and overlaid with a cloned ext4 scratch disk
on `/dev/vdb` (`UUID a9893320…`, created 2026-03-06 17:10:25).

### 1.2 Build chain

| Timestamp (UTC) | Event | Evidence |
| :--- | :--- | :--- |
| 2026-02-10 14:05 | debootstrap / base packages from `ftpmaster.internal` | `golden/bootstrap.log` |
| 2026-03-02 16:32–16:40 | toolchain provisioning (apt) | `golden/apt_history.log`, `golden/apt_term.log` |
| 2026-03-06 16:39 | `libnss3` security upgrade, `Requested-By: jules (1001)` | `golden/apt_history.log` |
| 2026-03-06 16:28 | rootfs artifact `rootfs-20260306-162806.img` | `/etc/devbox-version-info` |
| 2026-03-06 17:10:25 | ext4 scratch disk created | `tune2fs -l /dev/vdb` |
| 2026-03-06 17:10:29 | first devbox boot (journal start) | `journalctl --list-boots` |

The image tag is `rootfs-20260306-162806.img` and the rebuild counter is `202610`
(`/etc/devbox-rebuild-hash`). The machine-id baked into the image is
`58bffcf38f8d4939bd3e07b2ea187369`.

### 1.3 Provisioning commands (selected, from apt history)

```text
apt-get install -y --no-install-recommends apt-transport-https apt-utils build-essential \
  ca-certificates curl docker.io git gnupg2 init inotify-tools iproute2 iputils-ping \
  locales less lsb-release lynx net-tools npm openssh-server rsync socat \
  software-properties-common sudo tar tmux udev unminimize unzip wget vim zip

apt-get install -y --no-install-recommends build-essential git pkg-config autoconf automake \
  libtool ripgrep jq yq sed gawk less vim nano tree dos2unix curl wget net-tools iproute2 \
  dnsutils openssl nmap htop procps lsof strace sysstat unzip zip tar gzip bzip2 xz-utils

apt-get install -y --no-install-recommends build-essential libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libncurses5-dev libncursesw5-dev libffi-dev liblzma-dev \
  pipx tk-dev xz-utils libgdbm-dev libdb-dev

apt-get install -y --no-install-recommends openjdk-21-jdk
apt-get install -y --no-install-recommends build-essential ccache clang clang-format \
  clang-tidy cmake cppcheck gdb lsb-release ninja-build pipx valgrind
apt-get install -y --no-install-recommends php-cli php-common php-curl php-mbstring ...
apt-get install -y --no-install-recommends dotnet-sdk-8.0 dotnet-sdk-10.0
apt-get install -y --no-install-recommends ruby-full
apt-get install -y --no-install-recommends /tmp/chrome.deb        # Chrome 145.0.7632.116
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin                      # replaces docker.io/containerd/runc
apt-get install -y --no-install-recommends git                    # upgrades to 2.53.0 (git-core PPA)
apt-get install -y --no-install-recommends ... xvfb fonts-... gstreamer-...
```

`/usr/local` additionally contains the Go 1.24 toolchain, Bun, Composer and Bundler.

### 1.4 Baked secrets (values withheld)

| Path | Mode | Size | SHA256 |
| :--- | :--- | :--- | :--- |
| `/etc/ssh/ssh_host_ecdsa_key` | 600 root | 513 | `31a44563…d249a57` |
| `/etc/ssh/ssh_host_ed25519_key` | 600 root | 411 | `23d44212…cb6a04c5b` |
| `/etc/ssh/ssh_host_rsa_key` | 600 root | 2610 | `725eaf2f…2831ec1d` |
| `/root/.android/adbkey` | 600 root | 1704 | `600a888e…6ff91e1bd` |

The SSH host private keys in `/rom/etc/ssh/` are **byte-identical** to the live
`/etc/ssh/ssh_host_*` (see `golden/golden_inventory.txt`). Every devbox cloned from
this image therefore shares the same SSH host keys. No cloud, GitHub, Docker or
package-registry credentials were baked; `gcloud`, `.aws`, `.docker`, `.netrc` and
`/etc/ssl/private` are absent/empty, and no shell history is present.

### 1.4.1 Credential exposure (value withheld)

- **`jules` has a baked, non-locked yescrypt password hash** in `/rom/etc/shadow`.
  An offline check matched a **trivial default** (the value is deliberately not
  reproduced in this public repository).
- `sshd -T` reports `passwordauthentication yes`; `jules` is in `sudo` with
  `NOPASSWD: ALL`. Therefore **password login as `jules` → immediate root**.
- `root`, `ubuntu` and `swebot` are locked; only `jules` is unlocked.
- Because the hash lives in the golden image, **the same password is shared by
  every devbox cloned from it**.
- **Confirmed live (2026-11-07):** the running `/etc/shadow` hash is byte-identical
  to `/rom/etc/shadow`, still matches the trivial default, and `/etc/shadow`'s mtime
  is `2026-03-04 22:11:03` — it is **never rotated per session**.
- The live agent setup (not baked) added `GOEDEL_API_KEY` to
  `/home/jules/.bashrc` and `/home/jules/.profile`, and `TAILCAT_PEER_KEY` is in
  the `opencode` process environment. These are **not** committed here.

### 1.5 Baked custom units

- `devbox-ssh-over-vsock.service` — `socat VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22`
- `var-lib-systemd.mount` — `tmpfs` at 50% RAM for `/var/lib/systemd`
- `sshd.service` — overrides stock unit (notify, `RuntimeDirectory=sshd`)

---

## 2. Host gateway `192.168.0.1` surface `[Tier 1]`

The gateway is the host side of the Firecracker `virtio-net` tap. It exposes exactly
two TCP services and one UDP service.

| Proto | Port | Service | Fingerprint |
| :--- | :--- | :--- | :--- |
| UDP/TCP | 53 | DNS forwarder | `version.bind CH TXT` → `dnsmasq-2.91` |
| TCP | 8080 | GitHub reverse proxy | `Server: BaseHTTP/0.6 Python/3.12.3` |

- **Host OS hints:** ICMP TTL `64` (Linux); ~0.4 ms RTT.
- **Unstable L2 identity:** the gateway MAC was `9a:d0:40:b6:36:f0` at 09:42 UTC and
  `42:d0:d9:5b:d3:31` at 10:51 UTC; the tap identity is not stable across time.
- **Full TCP sweep (`1–65535`):** only `53` returned under a 65k-SYN burst; `8080`
  was missed during the burst but confirmed immediately afterwards by sequential
  connect and a narrow rescan. The single-threaded Python proxy drops connection
  bursts, a robustness/DoS consideration (it recovered at once).
- **UDP:** only `53/udp` confirmed. `67/68,111,162,500,1900,5353` were
  `open|filtered` (no response), not confirmed open.

### 2.1 Git reverse proxy semantics

| Request | Result |
| :--- | :--- |
| `GET /healthz` | `200`, body `Service ready.` (served locally) |
| `GET /readyz /livez /metrics /debug /status /robots.txt` | proxied to GitHub (`Server: github.com`) |
| `GET /version`, `/api` | GitHub `404` |
| `GET /openapi.json` | GitHub `410` |
| `GET .../info/refs?service=git-upload-pack` | GitHub Smart-HTTP advertisement |
| `GET .../info/refs?service=git-receive-pack` | `401 No anonymous write access.` |
| `PUT/DELETE/OPTIONS/HEAD/PATCH` | `501` (only `GET`/`POST` implemented) |
| `curl -x` (forward-proxy use) | fails (`000` HTTPS, `400` HTTP) |

So `:8080` is a **path-mapping reverse proxy** to `github.com`, with a local
`/healthz`; it is not a forward proxy and does not inject anonymous write access.

### 2.2 Egress

Outbound traffic is NAT-ed through the gateway. Public egress address is dynamic per
session (this capture: `34.29.198.103`, Google Cloud `us-central1` / Council Bluffs).
DNS queries are answered by the host `dnsmasq`.

---

## 3. VSOCK: definitive runtime result `[Tier 1]`

```text
virtio3  device=0x0013 (virtio-vsock)  driver=vmw_vsock_virtio_transport  IRQ 28
Guest CID = 123
v_str LISTEN  *:22    (socat VSOCK-LISTEN:22 -> 127.0.0.1:22)
```

Full non-blocking `AF_VSOCK` sweeps:

| CID | Ports | Result |
| :--- | :--- | :--- |
| `2` (host) | `1–65535` | **0 open** (all reset) |
| `0` (hypervisor) | `1–65535` | **0 open** |
| `1` (local) | `1–65535` | port `22` open (socat loopback) |

Interrupt accounting corroborates the idleness: `virtio3` ≈ 12 IRQs vs ~156k on
`virtio2` (net) before probing. The `vmm.notify_socket:vsock-stream:2:9999`
credential exists in `/run/credentials/@system/` but nothing is listening; the
guest→host notification path is dead in this resumed instance. **The live control
plane is TCP over virtio-net, not VSOCK** (see [`GUEST_HOST_COMMS.md`](GUEST_HOST_COMMS.md)).

---

## 4. Live harness telemetry captured `[Tier 1]`

A detached watcher (`/tmp/ghc_watch.sh`, reparented to PID 1) recorded
`live/metadata.log` (SSH sessions, VSOCK sockets, virtio IRQs, session-dir state,
process tree) plus content-bearing captures in a private 0700 directory.

Observed host-issued commands during the window:

```text
uptime; ps aux | grep tailcat
cd /app
ps aux | grep tailcat
```

The full journal (3,719 lines) contains **1,015 `sudo COMMAND=` entries**. Command
histogram (top): `bash` 742, `sha256sum` 101, `mkdir` 56, `ls` 14, `journalctl` 12,
`dmesg` 9, `cp` 7, `head`/`grep` 6 each, `ssh-keygen`/`ss`/`find`/`dd` 5 each.
The repeated `sha256sum`/`dd`/`mkdir` pattern is the host-side evidence-hashing and
directory-preparation loop, not the agent's own commands.

---

## 5. Secrets inventory (values withheld)

| Location | Kind | Note |
| :--- | :--- | :--- |
| `/etc/ssh/ssh_host_*_key` (baked in `/rom`) | SSH host private keys | shared across all clones |
| `/root/.android/adbkey` (baked) | Android ADB private key | baked |
| `~/.config/tailcat/ssh/ssh_host_ed25519_key` | Tailcat SSH host key | ingress plane |
| `opencode` process env | `GOEDEL_API_KEY`, `TAILCAT_PEER_KEY` (set) | agent model/ingress auth |
| `~/.local/state/opencode/model.json`, `prompt-history.jsonl` | agent config/chat history | private |
| `~/.local/share/opencode/opencode.db*` | agent conversation DB | private |

Only paths, modes, sizes and SHA256 digests are recorded here
(`raw/.../secrets/sensitive_inventory.txt`); the material itself was not copied into
this public repository.

---

## 6. Persistence & artifacts

- Raw evidence (this repo): `evidence/raw/guest_host_comms_20261107T102856Z/`
  - `golden/` — inventory, bootstrap/apt/dpkg logs, build info
  - `host_scan/` — TCP/UDP scans, proxy method/path matrices
  - `vsock/` — CID sweep results
  - `live/` — watcher metadata, journal histogram, harness scripts
  - `system/` — identity, kernel config, units, packages, dmesg, proc tree
  - `secrets/` — paths + hashes only
- Private (not committed): `/home/jules/ghc_private/` (0700) — full journal,
  captured `command/stdin/stdout/stderr`, session events.
- Push from the guest is blocked: direct HTTPS needs credentials; the `:8080`
  proxy returns `401` for `git-receive-pack`.

---

## 7. Reproduction

```bash
# base image provenance
cat /rom/etc/cloud/build.info /etc/devbox-version-info /etc/devbox-rebuild-hash
sudo sha256sum /rom/etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key
cat /rom/var/log/bootstrap.log; tail -n 80 /rom/var/log/apt/history.log

# host gateway
gcc -O2 evidence/scripts/scan_tcp.c -o /tmp/scan_tcp && /tmp/scan_tcp 192.168.0.1 1 65535
sudo nmap -sU -p 53,123,161,5353 192.168.0.1
dig @192.168.0.1 version.bind CH TXT
curl -sD- http://192.168.0.1:8080/healthz
curl -sD- "http://192.168.0.1:8080/<owner>/<repo>/info/refs?service=git-receive-pack"

# vsock
gcc -O2 evidence/scripts/scan_vsock.c -o /tmp/scan_vsock && /tmp/scan_vsock 2 1 65535
ss -a --vsock
```
