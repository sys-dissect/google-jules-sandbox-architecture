# Active Guest → Host Communication Channels

What the guest can actually **send to the host and get a valid response from**,
verified with request/response transcripts on 2026-11-07. Raw:
[`raw/guest_host_comms_20261107T102856Z/host_scan/`](raw/guest_host_comms_20261107T102856Z/host_scan/).

> Goal: establish first-contact dialogue with `192.168.0.1` (and host CID `2`),
> not just scan it.

---

## 1. Channel matrix

| Channel | Direction tried | Result |
| :--- | :--- | :--- |
| Virtio-VSOCK `CID 2` (with/without `VMADDR_FLAG_TO_HOST`) | guest → host | **closed** — all ports reset (full `1–65535` sweep = 0 open) |
| VSOCK `CID 1:22` | guest → local | **open** (local `socat` loopback only) |
| TCP `192.168.0.1:22` (SSH) | guest → host | closed |
| TCP `192.168.0.1:53` (DNS, UDP+TCP) | guest → host | **open — dialogue works** |
| TCP `192.168.0.1:8080` (HTTP reverse proxy) | guest → host | **open — host `/healthz` response** |
| ICMP echo | guest → host | **open — payload echoed verbatim** |
| ARP | guest → host | **open — host MAC returned** |
| UDP `:67/:68` DHCP | guest → host | no reply (DNS-only dnsmasq) |
| Full TCP sweep (`nmap -p-`) | guest → host | **only `53` and `8080`** |

The host is not reachable for an interactive shell: no VSOCK listener, no host SSH,
no DHCP, no other TCP services.

---

## 2. Persistent DNS dialogue (TCP/53) `[Tier 1]`

One TCP connection to `192.168.0.1:53`, three length-prefixed queries on the **same
socket** (`host_scan/dns_tcp_session.txt`):

```text
connected: ('192.168.0.2', 34930) -> ('192.168.0.1', 53)

[query 1] version.bind type=16 class=3 -> 55 bytes
id=0x4201 rcode=0 ancount=1
  TXT dnsmasq-2.91

[query 2] opencode-dialog-1.devbox-gateway.internal type=1 class=1 -> 75 bytes
id=0x4202 rcode=0 ancount=1
  A 192.168.0.1

[query 3] opencode-dialog-2.devbox-gateway.internal type=1 class=1 -> 75 bytes
id=0x4203 rcode=0 ancount=1
  A 192.168.0.1

socket still open after 3 exchanges: True
session closed by guest
```

So the host runs **dnsmasq 2.91** and speaks a normal DNS dialogue over both UDP and
TCP. It is authoritative for a **wildcard** under `devbox-gateway.internal`: any
`<anything>.devbox-gateway.internal` A query answers `192.168.0.1` (`flags: qr aa`).
SOA/NS/MX/TXT for that name are forwarded upstream (authority returned is the root
SOA). `version.bind`/`authors.bind` are answered locally (`dnsmasq-2.91` /
`Simon Kelley`). `hostname.bind` is empty.

> Consequence: the host resolver is a permissive bidirectional channel. Arbitrary
> labels are accepted (wildcard A), and non-local names are forwarded upstream, so
> DNS tunnelling / exfiltration through the host resolver is possible in principle.

---

## 3. HTTP dialogue with the host proxy (`:8080`) `[Tier 1]`

The host runs a Python reverse proxy (`Server: BaseHTTP/0.6 Python/3.12.3`). It has a
**host-generated** health endpoint and path-maps everything else to `github.com`.

```text
GET /healthz
HTTP/1.0 200 OK
Server: BaseHTTP/0.6 Python/3.12.3
Content-Type: text/html
X-Frame-Options: DENY
... GitHub headers (X-GitHub-Request-Id, x-github-edge-region: iad) ...

<html><body><h1>200 OK</h1>
Service ready.
</body></html>
```

- `POST /healthz` with body `hello-from-guest-OPENCODE` → same `200` + `Service ready.`
  (the host does not echo the body; it is not a command endpoint).
- `Host: example.com` → still GitHub content (Host ignored; path maps to `github.com`).
- Absolute-URI / forward-proxy request →

  ```text
  HTTP/1.0 400 Bad Request: Absolute URI with domain/scheme is not allowed.
  Server: BaseHTTP/0.6 Python/3.12.3
  ```

  i.e. the proxy explicitly refuses to act as a general forward proxy.
- `…/info/refs?service=git-receive-pack` → `401 No anonymous write access.`
- Curiously, even the local `/healthz` response carries GitHub headers and an
  anonymous `_gh_sess` cookie, indicating the host makes an upstream GitHub request
  while serving the health body.

---

## 4. ICMP echo — verified payload round-trip `[Tier 1]`

Raw ICMP echo request with a custom payload; the host echoed it byte-for-byte:

```text
reply from 192.168.0.1 type=0 code=0 id=25159 seq=1
sent payload   : OPENCODE_HOST_PROBE:9ff773a24a77
echoed payload : OPENCODE_HOST_PROBE:9ff773a24a77
MATCH
```

This is the cleanest **valid request/response** channel: the host IP stack receives
our bytes and returns them unchanged (TTL 64, ~0.3 ms). It is not an application
channel (no command execution), but it proves guest↔host L3 dialogue.

ARP resolves the same host at L2 (`ip neigh`: `42:d0:d9:5b:d3:31`), which is a
separate L2 round-trip.

---

## 5. DHCP — no service `[Tier 1]`

A well-formed `DHCPDISCOVER` (broadcast flag set, xid, hostname option) was sent to
both `255.255.255.255:67` and `192.168.0.1:67`, listening on `0.0.0.0:68`:

```text
sent DISCOVER to 255.255.255.255:67 (xid=0xb13cb354)
sent DISCOVER to 192.168.0.1:67 (xid=0xb13cb354)
no DHCP reply (host dnsmasq likely DNS-only)
```

So the host dnsmasq is **DNS-only**; the guest's static `ip=…:off` boot config is the
only address source.

---

## 6. What this means

- **No shell/command path into the host.** VSOCK CID 2 is fully closed (including
  with `VMADDR_FLAG_TO_HOST`), host SSH is closed, DHCP is off, and the only TCP
  services are DNS and the path-mapped GitHub proxy. The `swebot` control sessions
  are host-initiated; the guest cannot originate a control-plane session.
- **Valid host dialogues exist at L3/app layer:** ICMP echo (exact payload echo),
  DNS over UDP+TCP (including a persistent multi-query session), and HTTP to the
  host's own `/healthz`. These can be used for liveness checks, data round-trips,
  and DNS-based exfil testing.
- **The proxy is hardened against forward-proxy abuse** (absolute-URI 400, Host
  ignored) and requires auth for writes, but the DNS resolver is permissive
  (wildcard + upstream forwarding).

## 7. Reproduction

```bash
# DNS persistent TCP session
python3 evidence/scripts/dns_tcp_dialog.py   # three queries, one socket
dig @192.168.0.1 version.bind CH TXT +short
dig @192.168.0.1 anything.devbox-gateway.internal A +short   # -> 192.168.0.1

# HTTP host dialogue
curl -sD- http://192.168.0.1:8080/healthz
printf 'GET http://example.com/ HTTP/1.0\r\n\r\n' | socat - TCP4:192.168.0.1:8080

# ICMP payload round-trip
sudo python3 evidence/scripts/host_comms_probe.py

# definitive host surface
sudo nmap -n -sS -p- --min-rate 800 --max-retries 2 -T4 192.168.0.1
```
