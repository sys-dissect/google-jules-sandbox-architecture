# Tailcat SSH Execution Evidence

## Server Log (Sanitized Output)

```text
# Selected bootstrap relay region 301, New York City
2026/10/05 20:44:39 dns: using dns.noopManager
2026/10/05 20:44:39 link state: interfaces.State{defaultRoute=eth0 ifs={docker0:[172.17.0.1/16] eth0:[192.168.0.2/24 llu6]} v4=true v6=false}
2026/10/05 20:44:39 Creating WireGuard device...
2026/10/05 20:44:39 Bringing WireGuard device up...
2026/10/05 20:44:39 Starting network monitor...
2026/10/05 20:44:39 Engine created.
# 🐈 Server listening with new address: tcp[REDACTED_TAILCAT_ADDRESS]
2026/10/05 20:46:23 got meow from nodekey:[REDACTED]
2026/10/05 20:46:23 wg: [v2] peer(Tsy3…8Z1A) - Starting
2026/10/05 20:46:23 wg: [v2] peer(Tsy3…8Z1A) - Received handshake initiation
2026/10/05 20:46:23 wg: [v2] peer(Tsy3…8Z1A) - Sending handshake response
2026/10/05 20:46:23 [v1] Accept: TCP{[fd7a:115c:a1e0:4ecc:b7ef:99ae:64e5:b500]:47368 > [fd7a:115c:a1e0:7890:bf9b:2675:784a:860e]:22} 80 tcp ok
2026/10/05 20:47:15 got meow from nodekey:[REDACTED]
2026/10/05 20:47:15 magicsock: disco: node [QWn/7] d:[REDACTED] now using [REDACTED_CLIENT_ENDPOINT] mtu=1360 tx=[REDACTED]
2026/10/05 20:47:15 wg: [v2] peer(QWn/…iQH8) - Starting
2026/10/05 20:47:15 wg: [v2] peer(QWn/…iQH8) - Received handshake initiation
2026/10/05 20:47:15 wg: [v2] peer(QWn/…iQH8) - Sending handshake response
2026/10/05 20:47:15 [v1] Accept: TCP{[fd7a:115c:a1e0:4169:ffee:a4da:4e:d37c]:35396 > [fd7a:115c:a1e0:7890:bf9b:2675:784a:860e]:22} 80 tcp ok
2026/10/05 20:50:21 wg: [v2] peer(QWn/…iQH8) - Received handshake initiation
2026/10/05 20:50:21 wg: [v2] peer(QWn/…iQH8) - Sending handshake response
2026/10/05 20:50:21 [v1] Accept: TCP{[fd7a:115c:a1e0:4169:ffee:a4da:4e:d37c]:35396 > [fd7a:115c:a1e0:7890:bf9b:2675:784a:860e]:22} 204 tcp non-syn
```

## Observations and Audit Findings

1. **Inbound SSH Connections**:
   - Inbound WireGuard handshakes and TCP SSH connection attempts (port 22) succeeded.
   - Connections originated from authenticated peers (via Tailscale DERP relay in NYC and direct UDP pathing).
2. **Authorized Keys Validation**:
   - Tailcat allowed and accepted inbound connections against the supplied `--ssh-authorized-keys` parameter.
3. **Key Source Confirmation**:
   - The authorized public keys used were provided directly by the developer in the workload session. No unauthorized keys were generated or accepted.
4. **Architectural Implication**:
   - While the hypervisor enforces a strict inbound VSOCK-only boundary (`pci=off`, private network on `192.168.0.2`), the open outbound egress allows establishing encrypted peer-to-peer user-space tunnels (via WireGuard / Tailcat) to grant authorized developers interactive remote shell access directly into the active devbox microVM.

5. **User-Space Netstack Implementation (No Elevated Privileges Required)**:
   - Detailed server log examination reveals:
     ```text
     [v1] using fake (no-op) tun device
     [v2] netstack: registered IP fd7a:115c:...
     ```
   - **Mechanism**: Rather than creating a Linux kernel network adapter (`tun0`), Tailcat defaults to an in-process, pure user-space TCP/IP stack (**gVisor netstack**).
   - **Systems Consequence**: By operating netstack directly within user space, Tailcat bypasses the need for `CAP_NET_ADMIN` capabilities, kernel device allocation (`/dev/net/tun`), or root privileges to accept inbound SSH connections. WireGuard packets are decrypted and routed through the in-memory TCP stack directly into user-space listeners.

---

## 6. Deterministic Address Persistence Across Reboots & Redeploys

### The Address Drift Root Cause
By default, executing `tailcat serve` without explicit flags generates an ephemeral WireGuard private key in process memory and invokes dynamic STUN latency probing across available DERP relays (`--region=auto`). Consequently:
1. Every service restart or microVM reboot generates a new ephemeral public node key.
2. Jitter between DERP relays (e.g. NYC 31ms vs. SFO 40ms) can select a different relay region.
3. Because the Tailcat address string cryptographically encodes both the server public key and the DERP region ID, the address drifts on every restart, breaking external SSH tunnels and pairing configurations.

### The 4-Step Deterministic Persistence Blueprint

To ensure the Tailcat ingress address remains byte-identical across sandbox restarts, microVM reboots, and environment redeployments, follow this 4-step protocol:

#### 1. Install Tailcat in Persistent Storage (`home`, never `/usr/local/bin`)
In microVMs with immutable SquashFS roots or overlay filesystems (such as the Jules devbox), `/usr/local/bin` resides on the base image or may be reset. In contrast, `$HOME` (`/home/jules`) resides on the persistent writable scratch partition (`/dev/vdb` ext4 upperdir).
```bash
mkdir -p ~/.local/bin ~/.config/tailcat/keys
cp -p ~/go/bin/tailcat ~/.local/bin/tailcat
chmod +x ~/.local/bin/tailcat
```

#### 2. Generate a Region-Pinned Key
Bake a fixed DERP relay region into the persistent key file:
```bash
# Pick the region closest to the developer (e.g., tok, nyc, fra, sfo)
tailcat genkey --key=default --region=tok
```
* **Why this works**: Tailcat saves the private key, public node key, and fixed `RegionID` into `~/.config/tailcat/keys/default.private.json`.
* **The Magic Name**: The key name `"default"` is automatically loaded by `tailcat serve` on startup, making address selection fully deterministic.

#### 3. Run as a Systemd Service with Sandbox-Local Egress Proxies
Cloud sandboxes often enforce egress HTTP/SOCKS proxies (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`) containing short-lived authentication tokens. **Never copy proxy environment variables from another VM**, as those credentials rotate and belong to distinct sandbox sessions.

The service must capture the active sandbox environment dynamically:
```ini
# /etc/systemd/system/tailcat.service
[Unit]
Description=Tailcat Persistent Ingress Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=jules
WorkingDirectory=/home/jules
# Sandbox-local proxy variables injected here (if present in local env)
ExecStart=/home/jules/.local/bin/tailcat serve --key=default --files=/home/jules:rw --ssh-authorized-keys="<developer_public_keys>" ssh,files
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```
* Enabling `--files=/home/jules:rw` enables dual SSH and SFTP file-transfer capabilities (`tailcat ssh`, `tailcat cp`, `tailcat ls`).

#### 4. Post-Redeploy Verification via Canonical Address Resolution
After every redeploy or reboot, verify the service output via `journalctl`:
```bash
journalctl -u tailcat.service | grep "Server listening"
```
**Critical Verification Rule:** Always resolve both tokens to canonical format (`tailcat resolve <addr>`) before comparing:
```bash
# Resolve runtime token and saved token to canonical format:
RESOLVED_RUNTIME=$(tailcat resolve "$RUNTIME_ADDR")
RESOLVED_SAVED=$(tailcat resolve "$SAVED_ADDR")

# Compare byte-identical:
if [ "$RESOLVED_RUNTIME" = "$RESOLVED_SAVED" ]; then
    echo "[VERIFIED] Address matches byte-identically!"
fi
```
Never compare a short address token directly against an expanded resolved token; both formats represent the same endpoint, but must be compared resolved-vs-resolved.

---

## 7. Automated Reproduction Script

A reference implementation automating this entire 4-step persistence ritual is available in the repository at [`scripts/install_persistent_tailcat.sh`](../scripts/install_persistent_tailcat.sh):

```bash
# Export authorized SSH public key(s)
export TAILCAT_AUTHORIZED_KEYS="ssh-ed25519 AAAA... developer@workstation"

# Run installer pinned to Tokyo region (or omit for default)
./scripts/install_persistent_tailcat.sh tok
```

### Verified Live Endpoints (Redacted Example):
* **Region-Pinned Key:** `/home/jules/.config/tailcat/keys/default.private.json` (`RegionID: 304`, Tokyo)
* **Short Address Token:** `tcpGFwW...[REDACTED]...FpGQEw`
* **Canonical Resolved Address:** `tcpGFwW...[REDACTED]...zE4OA`
