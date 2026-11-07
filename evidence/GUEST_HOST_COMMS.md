# Guest ↔ Host Communication Plane

Live re-audit of the data paths between the guest devbox and the host orchestration plane, captured from inside a warm-resumed Jules microVM on **2026-11-07** (guest CID `123`, `boot_id 368a2f92-8fdb-4f81-8993-1ac81a2e3759`, `/dev/vda` SHA256 `227f52bb892b5000bbe394f6210d66aae0f2e90bfe0723c30b71f5115c69c098`).

This document supplements [`SYSTEMD_AND_HARNESS_IPC.md`](SYSTEMD_AND_HARNESS_IPC.md), [`FIRECRACKER_AND_VSOCK.md`](FIRECRACKER_AND_VSOCK.md), and [`SNAPSHOT_AND_PROXY_DEEPDIVE.md`](SNAPSHOT_AND_PROXY_DEEPDIVE.md), and refines the assumption that the orchestrator control plane runs over Virtio‑VSOCK.

> **Provenance note:** this capture was taken on the same golden image and scratch-disk lineage as the rest of the study (`/dev/vda` hash matches [`raw/golden_delta/vda_sha256.txt`](raw/golden_delta/vda_sha256.txt); `/dev/vdb` UUID `a9893320-…`, created 2026‑03‑06 17:10:25). Because the VM is resumed from a warm snapshot rather than cold-booted, the boot-time VSOCK notification channel is not re-established (see §3).

---

## 0. Summary

| Path | Transport | Observed state |
| :--- | :--- | :--- |
| Host → guest orchestrator SSH | **TCP over virtio-net** `192.168.0.1:* → 192.168.0.2:22` | **Active** — 3 long-lived sessions `swebot@notty` |
| Host → guest VSOCK SSH | `AF_VSOCK` `CID 2:22` → `socat` → `127.0.0.1:22` | **Idle** — listener only, no established sockets |
| Guest → host VMM notify | `AF_VSOCK` `CID 2:9999` (`vmm.notify_socket`) | **Dead** — `ECONNRESET` at runtime |
| Guest → host DNS | UDP/TCP `192.168.0.1:53` | **Active** |
| Guest → host Git proxy | HTTP `192.168.0.1:8080` (reverse proxy) | **Available**, not wired into guest git by default |
| Guest → Internet | NAT via `192.168.0.1` | **Active** (dynamic GCP `us-central1` egress) |
| Interactive agent ingress | **Tailcat** user-space WireGuard over outbound `:443` | **Active** (spawns `opencode` on `pts/2`) |

```
                     HOST (192.168.0.1 / CID 2)                  GUEST (192.168.0.2 / CID 123)
 ┌────────────────────────────────────────────────────────┐  ┌──────────────────────────────────────────────┐
 │ Jules orchestrator (swebot)                             │  │                                              │
 │   │                                                     │  │                                              │
 │   ├── TCP 192.168.0.1:* ───────────────────────────────┼─►│ sshd :22 (ssh.socket, systemd-activated)     │
 │   │     publickey RSA SHA256:+76aRhv…  → swebot        │  │   └─ sshd: swebot@notty (3 persistent)       │
 │   │     (no VSOCK used for these sessions)              │  │        └─ sudo → /run/devbox-session/default │
 │   │                                                     │  │             command/stdin → tmux → outputs    │
 │   ├── DNS  UDP/TCP :53 ◄────────────────────────────────┼──│ /etc/resolv.conf → nameserver 192.168.0.1    │
 │   ├── Git reverse proxy :8080 ◄─────────────────────────┼──│ optional via url.insteadOf                   │
 │   ├── NAT egress → Internet                             │  │                                              │
 │   └── VSOCK CID 2:9999 ✗ RST ◄──────────────────────────┼──│ credential vsock-stream:2:9999              │
 │       VSOCK CID 2:22,53,… ✗ RST                         │  │ socat VSOCK-LISTEN:22 → 127.0.0.1:22 (idle) │
 └────────────────────────────────────────────────────────┘  └──────────────────────────────────────────────┘
                                                                   ▲
                            Tailcat WireGuard (gVisor netstack) ───┘  pts/2 → opencode
                            outbound :443 → DERP relay
```

---

## 1. Host → Guest control plane is TCP over virtio-net `[Tier 1]`

The orchestrator reaches guest `sshd` directly across the emulated NIC. It does **not** use the VSOCK bridge for these sessions.

```bash
$ sudo ss -tnp 'sport = :22'
State Recv-Q Send-Q Local Address:Port   Peer Address:Port  Process
ESTAB 0      0      192.168.0.2:22       192.168.0.1:55964   users:(("sshd",pid=17721,fd=4),("sshd",pid=17710,fd=4))
ESTAB 0      0      192.168.0.2:22       192.168.0.1:43716   users:(("sshd",pid=929,fd=4),("sshd",pid=918,fd=4))
ESTAB 0      0      192.168.0.2:22       192.168.0.1:58898   users:(("sshd",pid=907,fd=4),("sshd",pid=877,fd=4))
```

Authentication is a shared public key, not a host-issued credential:

```text
sshd[877]: Accepted publickey for swebot from 192.168.0.1 port 58898 ssh2:
           RSA SHA256:+76aRhvNghBah8rUnsutpDfo+xt9BatCwzBu2auwy5I
```

The same fingerprint is present in `/root/.ssh/authorized_keys`, `/home/jules/.ssh/authorized_keys`, and `/home/swebot/.ssh/authorized_keys`, and `PermitRootLogin without-password` is enabled — the host can authenticate as `swebot` or as `root` with the same key.

Inbound SSH is **socket-activated** (`ssh.socket` enabled; systemd PID 1 holds `0.0.0.0:22` and `[::]:22`), so connections are accepted by PID 1 and handed to `ssh.service`.

### 1.1 `swebot` is an alias of `jules`

```text
jules:x:1001:1001::/home/jules:/bin/bash
swebot:x:1001:1001::/home/jules:/bin/bash
lrwxrwxrwx 1 root root 11 Mar  4  2026 /home/swebot -> /home/jules
```

`swebot` shares UID/GID `1001` and the same home directory as `jules`, and both have `NOPASSWD: ALL`. It is an account name used to distinguish the orchestrator login, not a privilege boundary.

### 1.2 Harness bootstrap

At session start the host, as `swebot` (escalating via passwordless sudo), rewrites DNS and probes the gateway services:

```bash
set -xe
echo nameserver 192.168.0.1 > /etc/resolv.conf
timeout 1s socat /dev/null TCP4:devbox-gateway.internal:53
timeout 1s socat /dev/null TCP4:192.168.0.1:8080
```

### 1.3 Command/response protocol (file-piped FIFO)

1. **Ingress** — the host writes the instruction and stdin:

   ```bash
   cat > /run/devbox-session/default/command
   cat > /run/devbox-session/default/stdin
   ```

2. **Injection** — the host runs, as `jules`, a wrapper that installs a one-shot `PROMPT_COMMAND` and pastes the command into tmux:

   ```bash
   COMMAND="PROMPT_COMMAND='__CODExx__=$?; echo \$__CODExx__ > /run/devbox-session/default/exit_code && touch /run/devbox-session/default/stamp; unset PROMPT_COMMAND;'
   source /run/devbox-session/default/command < /run/devbox-session/default/stdin > /run/devbox-session/default/stdout 2> /run/devbox-session/default/stderr"
   printf '%s\n' "${COMMAND}" | tmux load-buffer -
   tmux paste-buffer -t default
   tmux send-keys -t default Enter
   ```

3. **Harvest** — when the shell prompt returns, `stamp` appears; the host-side `inotifywait` unblocks and reads `exit_code`, `stdout`, and `stderr`.

4. **Workspace telemetry** — the host repeatedly snapshots the working tree as `jules`:

   ```bash
   cd /app
   git add -A
   git diff --minimal --binary -U3 984c37df2d061d4c6110da689844fed47890c2b2
   ```

   This loop was observed rotating roughly every two seconds during active turns, i.e. the guest→host channel continuously streams binary working-tree diffs in addition to command output.

---

## 2. Guest → Host VSOCK is not reachable at runtime `[Tier 1]`

The VSOCK device is present and correctly bound, but carries essentially no traffic.

```text
virtio3   device=0x0013 (virtio-vsock)   driver=vmw_vsock_virtio_transport   IRQ 28 (IO-APIC 8)
/dev/vsock major 10 minor 126
Guest CID = 123  (IOCTL_VM_SOCKETS_GET_LOCAL_CID)
```

Interrupt accounting before VSOCK probing:

```text
25: virtio0 (vda)     47,688
26: virtio1 (vdb)     23,050
27: virtio2 (net)    155,977
28: virtio3 (vsock)       12   <-- ~0 traffic
```

The only VSOCK socket is the local listener:

```bash
$ ss -a --vsock
Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:Port
v_str LISTEN 0      0      *:22                *:*
```

No `ESTAB` VSOCK sockets exist, while the three orchestrator sessions above are plain TCP.

### 2.1 Guest→host port probe

A non-blocking `AF_VSOCK` connect probe (1.5 s timeout) against host CID `2` returns `ECONNRESET` for every tested port:

| CID | Ports tested | Result |
| :--- | :--- | :--- |
| `2` (host) | `22, 53, 80, 443, 1024, 2375, 5000, 8000, 8080, 9999, 10000` | `ECONNRESET` (none reachable) |
| `1` (local) | `22` | **OPEN** (loopback to the `socat` listener) |

Connecting to the VMM notification socket also fails:

```bash
$ socat -d -d - VSOCK-CONNECT:2:9999 </dev/null
socat[38474] N VSOCK CID=123
socat[38474] N opening connection to AF=40 cid:2 port:9999
socat[38474] E connect(5, AF=40 cid:2 port:9999, 16): Connection reset by peer
```

The credential itself is present and correctly formed:

```bash
$ cat /run/credentials/@system/vmm.notify_socket
vsock-stream:2:9999
```

### 2.2 Interpretation

- The `systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999` channel is a **boot/lifecycle notification** path, not a general-purpose guest→host RPC bus.
- In this resumed instance no host-side CID 2 listener is reachable. This is consistent with a warm snapshot restore: the guest retains the credential and the original `boot_id`/journal, but the host-side VSOCK endpoint is not re-bound.
- The `devbox-ssh-over-vsock.service` bridge (`socat VSOCK-LISTEN:22 …`) remains provisioned and works for local (`CID 1`) traffic, but it is **not** the path used by the live orchestrator sessions.

---

## 3. Guest → Host services over virtio-net `[Tier 1]`

### 3.1 DNS

`192.168.0.1:53` is open on both UDP and TCP and answers recursively. The boot harness pins it as the sole resolver:

```bash
$ cat /etc/resolv.conf
nameserver 192.168.0.1

$ nslookup github.com 192.168.0.1
Server:   192.168.0.1
Address:  192.168.0.1#53
Name:     github.com
Address:  140.82.114.4
```

Repeated queries return rotating GitHub addresses, consistent with a forwarding/round-robin resolver rather than static split-horizon entries.

### 3.2 Git reverse proxy (`192.168.0.1:8080`)

A host-side HTTP reverse proxy written in Python (not a forward proxy):

```text
Server: BaseHTTP/0.6 Python/3.12.3
```

- **Local health endpoint:** `GET /healthz` → `200 OK`, body `Service ready.`
- **Everything else is proxied to `github.com`:** `GET /version` returns GitHub's `404`, `GET /status` returns a GitHub HTML page, and the Git Smart-HTTP endpoint works end to end:

  ```text
  GET /sys-dissect/google-jules-sandbox-architecture/info/refs?service=git-upload-pack
  HTTP/1.0 200 OK
  Server: GitHub-Babel/3.0
  Content-Type: application/x-git-upload-pack-advertisement
  x-github-edge-region: iad

  001e# service=git-upload-pack
  00000159… HEAD multi_ack thin-pack side-band …
  ```

- **It is not a forward proxy:** `curl -x http://192.168.0.1:8080 https://github.com/` fails (`000`); plain-HTTP proxying returns `400`.
- **Write access is not anonymous:** `…?service=git-receive-pack` returns `401` with `No anonymous write access.`, i.e. the proxy forwards GitHub's auth challenge rather than injecting a token for the guest.
- **The guest is not configured to use it by default:** there is no `http_proxy`/`HTTPS_PROXY`, no credential helper, and no `url.*.insteadOf`. Direct `git ls-remote` resolves `github.com` and connects straight to `140.82.113.3:443` over TLS 1.3 with no `Authorization` header. Routing git through the proxy works only when explicitly configured, e.g.:

  ```bash
  git -c url.http://192.168.0.1:8080/.insteadOf=https://github.com/ ls-remote <repo>
  ```

### 3.3 NAT egress

Outbound traffic is NAT-ed through the host tap `192.168.0.1`. The public address is dynamic per session (this capture: `34.29.198.103`, Google Cloud `us-central1` / Council Bluffs); the region is stable, the address is not.

---

## 4. Interactive ingress is a separate plane (Tailcat) `[Tier 1]`

The human/agent session does **not** traverse the swebot control plane. Process ancestry shows it arriving through the Tailcat tunnel that was started inside the tmux session:

```text
systemd(1)
 └─ tmux(2799) "default"
     └─ bash(2800)
         └─ tailcat(10554) serve --ssh-authorized-keys=…
             └─ bash -l(25359, pts/2)
                 └─ opencode(25585)
                     └─ tool shells
```

- `tailcat` holds an outbound `ESTAB` connection to its DERP relay on `:443` and uses a **gVisor user-space netstack** (no `/dev/net/tun`, no `CAP_NET_ADMIN`).
- The inbound SSH authorized keys are supplied at launch by the developer (`onkar@fedora-to-raspberrypi`, `u0_a451@localhost`, `hatch ssh`), matching [`TAILCAT_SSH.md`](TAILCAT_SSH.md).
- This is why the interactive shell appears on `pts/2` while the orchestrator sessions are TTY-less `sshd: swebot@notty` sockets.

---

## 5. Corrections / refinements to prior documentation

1. **Host→guest IPC is not VSOCK.** The live orchestrator sessions are TCP over virtio-net (`192.168.0.1 → 192.168.0.2:22`). The VSOCK `socat` bridge exists but is idle. See §1.
2. **Host CID 2 is not currently listening on `9999`.** The `vmm.notify_socket` credential exists, but `CID 2:9999` (and every other tested CID 2 port) resets. See §2.
3. **The "VSOCK-only inbound boundary" does not hold for host→guest.** Guest `sshd` is reachable directly on the private NIC from the host tap, and is socket-activated. See §1.
4. **`swebot` is an alias of `jules`** (same UID/GID/home) and shares the root authorized key; it is not a separate security principal. See §1.1.
5. **The harness is richer than the FIFO description:** commands are injected via `tmux load-buffer`/`paste-buffer`/`send-keys`, and the working-tree diff is streamed continuously with `git add -A` + `git diff --minimal --binary`. See §1.3.
6. **The `:8080` Git service is a reverse proxy**, not a forward proxy, and is not wired into guest git by default; write operations are not anonymously available. See §3.2.

These findings do not change the core physical architecture (Firecracker, `pci=off`, Virtio-MMIO, SquashFS + ext4 overlay, guest CID 123); they correct the transport used by the control plane.

---

## 6. Reproduction

```bash
# 1. Map the inbound control plane
sudo ss -tnp 'sport = :22'
sudo journalctl -b | grep -E 'Accepted publickey for swebot'
sudo sshd -T | grep -E 'permitrootlogin|passwordauthentication'
systemctl is-enabled ssh.socket ssh.service

# 2. Prove the VSOCK bridge is idle
cat /proc/interrupts | grep virtio
ss -a --vsock                       # only v_str LISTEN *:22
socat -d -d - VSOCK-CONNECT:2:9999 </dev/null   # ECONNRESET

# 3. Enumerate guest->host VSOCK services
#    (non-blocking AF_VSOCK connect to CID 2 across candidate ports)

# 4. Inspect the gateway services
cat /etc/resolv.conf
curl -sD- http://192.168.0.1:8080/healthz
curl -sD- "http://192.168.0.1:8080/<owner>/<repo>/info/refs?service=git-upload-pack" | head
curl -sD- "http://192.168.0.1:8080/<owner>/<repo>/info/refs?service=git-receive-pack" | head

# 5. Reconstruct the harness protocol
sudo journalctl -b | grep -E 'devbox-session/default|PROMPT_COMMAND|tmux (load|paste|send)'

# 6. Trace the interactive ingress
ps -eo pid,ppid,user,tty,cmd --forest | grep -A6 -E 'tailcat|opencode'
sudo ss -tnp | grep -E 'tailcat|opencode'
```

---

## 7. Raw telemetry (sanitized)

```text
# /proc/interrupts (before probes)
25: virtio0 47,688 | 26: virtio1 23,050 | 27: virtio2 155,977 | 28: virtio3 12

# inbound SSH (root view)
ESTAB 192.168.0.2:22 <- 192.168.0.1:55964  sshd 17710/17721
ESTAB 192.168.0.2:22 <- 192.168.0.1:43716  sshd 918/929
ESTAB 192.168.0.2:22 <- 192.168.0.1:58898  sshd 877/907

# auth
Accepted publickey for swebot from 192.168.0.1 port 58898 ssh2:
  RSA SHA256:+76aRhvNghBah8rUnsutpDfo+xt9BatCwzBu2auwy5I

# identity
jules:x:1001:1001::/home/jules:/bin/bash
swebot:x:1001:1001::/home/jules:/bin/bash
/home/swebot -> /home/jules

# vsock
v_str LISTEN 0 0 *:22 *:*
CID 2:9999 -> connect: Connection reset by peer
/run/credentials/@system/vmm.notify_socket = vsock-stream:2:9999

# gateway
DNS 192.168.0.1:53  OPEN (UDP+TCP)
HTTP 192.168.0.1:8080  /healthz -> 200 "Service ready."
                        git-upload-pack -> 200 application/x-git-upload-pack-advertisement
                        git-receive-pack -> 401 "No anonymous write access."

# interactive ingress
tailcat(10554) -> bash -l(25359, pts/2) -> opencode(25585)
tailcat ESTAB 192.168.0.2:* -> DERP relay :443
```

> The public SSH key material is intentionally omitted; only its fingerprint is reproduced, consistent with the rest of the evidence corpus.
