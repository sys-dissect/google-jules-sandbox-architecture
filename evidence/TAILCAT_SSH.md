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
# 🐈 Server listening with new address: <address>
2026/10/05 20:46:23 got meow from nodekey:[REDACTED]
2026/10/05 20:46:23 wg: [v2] peer(Tsy3…8Z1A) - Starting
2026/10/05 20:46:23 wg: [v2] peer(Tsy3…8Z1A) - Received handshake initiation
2026/10/05 20:46:23 wg: [v2] peer(Tsy3…8Z1A) - Sending handshake response
2026/10/05 20:46:23 [v1] Accept: TCP{[fd7a:115c:a1e0:4ecc:b7ef:99ae:64e5:b500]:47368 > [fd7a:115c:a1e0:7890:bf9b:2675:784a:860e]:22} 80 tcp ok
2026/10/05 20:47:15 got meow from nodekey:[REDACTED]
2026/10/05 20:47:15 magicsock: disco: node [QWn/7] d:[REDACTED] now using [REDACTED] mtu=1360 tx=[REDACTED]
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
   - Connections originated from peers `[Tsy37]` and `[QWn/7]` (e.g. peer endpoint `[REDACTED]`).
2. **Authorized Keys**:
   - Tailcat allowed and accepted inbound connections against the supplied `--ssh-authorized-keys` parameter.
3. **Key Source Confirmation**:
   - The authorized public keys used were provided directly by the user in the prompt instructions (`ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE7UMbg/h++f8V0Y2n4vdp7hahxkKuUy2JuSnlhVIg89 [REDACTED]`, `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjyJnzKT3ta2HqxIcRM7ir9i6Sxdccq3JMJtkWsZJ9j u0_a451@localhost`, and `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMU15YSbGpEQvbADLn+dStxC6xfcXIjMs9lawF7B+oyP hatch`). None were generated in this session.
