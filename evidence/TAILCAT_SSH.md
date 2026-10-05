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
