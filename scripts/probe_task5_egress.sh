#!/usr/bin/env bash
set -euo pipefail
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="evidence/raw/task5_egress_${TS}"
mkdir -p "$OUT_DIR"
ip -4 addr > "$OUT_DIR/ip4.txt"
ip -6 addr > "$OUT_DIR/ip6.txt"
ip -4 route > "$OUT_DIR/route4.txt"
ip -6 route > "$OUT_DIR/route6.txt"
cat /etc/resolv.conf > "$OUT_DIR/resolv.conf"
curl -sS --max-time 5 https://ipinfo.io/json > "$OUT_DIR/egress_ipinfo.json" 2>&1 || true
curl -6 -sS --max-time 5 https://v6.ident.me > "$OUT_DIR/egress_ipv6.txt" 2>&1 || true
# TCP port matrix
python3 - << 'EOF' > "$OUT_DIR/tcp_port_matrix.jsonl"
import json, socket, time
targets = [
    ("1.1.1.1", 53, "cloudflare_dns_tcp"),
    ("8.8.8.8", 53, "google_dns_tcp"),
    ("1.1.1.1", 80, "cloudflare_http"),
    ("1.1.1.1", 443, "cloudflare_https"),
    ("github.com", 22, "github_ssh_22"),
    ("alt1.gmail-smtp-in.l.google.com", 25, "smtp_25"),
    ("smtp.gmail.com", 465, "smtps_465"),
    ("smtp.gmail.com", 587, "submission_587"),
    ("portquiz.net", 8080, "high_port_8080"),
    ("portquiz.net", 8443, "high_port_8443"),
    ("169.254.169.254", 80, "imds_link_local"),
    ("192.168.0.1", 80, "gateway_80"),
    ("192.168.0.1", 8080, "gateway_8080")
]
for host, port, label in targets:
    t0 = time.time()
    try:
        with socket.create_connection((host, port), timeout=3.0):
            status = "open"
    except Exception as e:
        status = f"error: {type(e).__name__}: {e}"
    print(json.dumps({"label": label, "host": host, "port": port, "status": status, "latency_ms": round((time.time()-t0)*1000, 1)}))
EOF
# UDP & DNS checks (system resolver vs direct 8.8.8.8 vs DoH)
python3 - << 'EOF' > "$OUT_DIR/udp_and_dns_matrix.jsonl"
import json, socket, struct, urllib.request
def dns_query_udp(server, port=53):
    q = b"\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01"
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(3.0)
    try:
        s.sendto(q, (server, port))
        data, _ = s.recvfrom(512)
        return f"ok_bytes_{len(data)}"
    except Exception as e:
        return f"err_{e}"
    finally:
        s.close()
print(json.dumps({"test": "udp_dns_192.168.0.1", "res": dns_query_udp("192.168.0.1")}))
print(json.dumps({"test": "udp_dns_8.8.8.8", "res": dns_query_udp("8.8.8.8")}))
print(json.dumps({"test": "udp_dns_1.1.1.1", "res": dns_query_udp("1.1.1.1")}))
try:
    req = urllib.request.Request("https://cloudflare-dns.com/dns-query?name=example.com&type=A", headers={"Accept": "application/dns-json"})
    body = urllib.request.urlopen(req, timeout=4).read().decode("utf-8", errors="replace")
    print(json.dumps({"test": "doh_cloudflare", "res": "ok", "sample": body[:160]}))
except Exception as e:
    print(json.dumps({"test": "doh_cloudflare", "res": f"err_{e}"}))
EOF
ping -c 3 -W 2 1.1.1.1 > "$OUT_DIR/icmp_ping.txt" 2>&1 || true
(cd "$OUT_DIR" && sha256sum * > SHA256SUMS.txt)
