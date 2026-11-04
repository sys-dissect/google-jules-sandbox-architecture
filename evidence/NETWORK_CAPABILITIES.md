# Network Capabilities & Routing Subsystem Audit

Direct empirical inspection of routing tables, boot parameters, gateway services, and public network egress.

---

## 1. Routing Table & Policy Rules

### Routing Table (`ip route show table all`)
```text
default via 192.168.0.1 dev eth0
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
192.168.0.0/24 dev eth0 proto kernel scope link src 192.168.0.2
local 127.0.0.0/8 dev lo table local proto kernel scope host src 127.0.0.1
local 127.0.0.1 dev lo table local proto kernel scope host src 127.0.0.1
broadcast 127.255.255.255 dev lo table local proto kernel scope link src 127.0.0.1
local 172.17.0.1 dev docker0 table local proto kernel scope host src 172.17.0.1
broadcast 172.17.255.255 dev docker0 table local proto kernel scope link src 172.17.0.1 linkdown
local 192.168.0.2 dev eth0 table local proto kernel scope host src 192.168.0.2
broadcast 192.168.0.255 dev eth0 table local proto kernel scope link src 192.168.0.2
local ::1 dev lo proto kernel metric 0 pref medium
local fe80::400:c0ff:fea8:2 dev eth0 proto kernel metric 0 pref medium
fe80::/64 dev eth0 proto kernel metric 256 pref medium
multicast ff00::/8 dev eth0 proto kernel metric 256 pref medium
```

### Policy Routing Rules (`ip rule`)
```text
0:      from all lookup local
32766:  from all lookup main
32767:  from all lookup default
```
Standard Linux single-table forwarding with default route pointed to the hypervisor gateway `192.168.0.1`.

---

## 2. Static Boot Routing Configuration

Networking in Google Jules completely bypasses DHCP or dynamic network managers (such as Netplan or systemd-networkd).

Network addressing is statically configured via kernel boot arguments:
```text
ip=192.168.0.2::192.168.0.1:255.255.255.0::eth0:off
```

* **Client IP:** `192.168.0.2`
* **Default Gateway:** `192.168.0.1`
* **Netmask:** `255.255.255.0` (`/24`)
* **Interface:** `eth0` (Virtio-Net MMIO at `0xc0003000`, IRQ 7)
* **Autoconf:** `off` (Zero DHCP latency, initialized during early kernel init)

---

## 3. Host Gateway (192.168.0.1) Architecture & Port Probe

The host gateway at `192.168.0.1` acts as a multi-role orchestration nexus:
1. **DNS Resolver / Forwarder (Port 53)**: Intercepts guest DNS queries and forwards upstream.
2. **Transparent Git Reverse Proxy (Port 8080)**: Python-based HTTP reverse proxy (`Server: BaseHTTP/0.6 Python/3.12.3`) intercepting Git operations and injecting credentials.
3. **NAT Default Gateway**: Routes guest egress out to Google Cloud Platform (`us-central1`).

### Gateway Port Sweep Results (`evidence/raw_telemetry/final_pass/gateway_ports.txt`)
```text
Port 22: CLOSED
Port 53: OPEN   (DNS resolver daemon)
Port 80: CLOSED
Port 443: CLOSED
Port 8080: OPEN  (Python Git proxy)
Port 9999: CLOSED
```

---

## 4. Outbound Public Egress Capabilities

Unlike air-gapped sandboxes (such as Gemini Spark), Google Jules provides extensive, unfiltered outbound network access:

### TUN/TAP Virtual Networking
```bash
$ ls -l /dev/net/tun
crw-rw-rw- 1 root root 10, 200 Mar 6 2026 /dev/net/tun
```
Full `/dev/net/tun` support permits creating user-space network devices, VPN tunnels (e.g. WireGuard/Tailscale), and virtual adapters.

### UDP Egress
```bash
$ nc -z -v -u -w 3 8.8.8.8 53
Connection to 8.8.8.8 53 port [udp/domain] succeeded!
```
Full outbound UDP packet forwarding is operational.

### Standard & Non-Standard TCP Egress
```bash
$ nc -z -v -w 3 portquiz.net 8080
Connection to portquiz.net (35.180.139.74) 8080 port [tcp/http-alt] succeeded!
```
Egress is open across standard (80, 443) and arbitrary high ports (8080, 2222, etc.), enabling dependency downloads from npm, PyPI, Maven, Go proxy, Docker Hub, and arbitrary third-party APIs. Outbound egress IP resolves to GCP Google Cloud NAT in region `us-central1`.
