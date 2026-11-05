#!/usr/bin/env bash
set -euo pipefail
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BOOT_ID="$(cat /proc/sys/kernel/random/boot_id | tr -d '-')"
OUT_DIR="evidence/raw/fleet_${TS}_${BOOT_ID:0:8}"
mkdir -p "$OUT_DIR"
echo "timestamp_utc=$TS" > "$OUT_DIR/meta.env"
echo "boot_id=$BOOT_ID" >> "$OUT_DIR/meta.env"
echo "uptime_s=$(cat /proc/uptime)" >> "$OUT_DIR/meta.env"
echo "uptime_since=$(uptime -s 2>/dev/null || true)" >> "$OUT_DIR/meta.env"
echo "uname=$(uname -a)" >> "$OUT_DIR/meta.env"
cat /proc/cpuinfo > "$OUT_DIR/cpuinfo.txt"
grep -H . /sys/devices/system/cpu/vulnerabilities/* > "$OUT_DIR/cpu_vulnerabilities.txt" 2>/dev/null || true
grep -H . /sys/devices/system/cpu/cpu0/cache/index*/* > "$OUT_DIR/cpu_cache_topology.txt" 2>/dev/null || true
grep -H . /sys/devices/system/clocksource/clocksource0/* > "$OUT_DIR/clocksource.txt" 2>/dev/null || true
sudo python3 - << 'EOF' > "$OUT_DIR/cpuid_leaves.txt" 2>&1 || true
import os, struct
fd = os.open("/dev/cpu/0/cpuid", os.O_RDONLY)
for leaf in [0x0, 0x1, 0x7, 0x80000002, 0x80000003, 0x80000004] + list(range(0x40000000, 0x40000011)):
    try:
        os.lseek(fd, leaf, os.SEEK_SET)
        data = os.read(fd, 16)
        eax, ebx, ecx, edx = struct.unpack("<IIII", data)
        raw_ascii = b"".join(struct.pack("<I", r) for r in (ebx, ecx, edx)).decode("latin1", errors="replace")
        print(f"leaf=0x{leaf:08x} eax=0x{eax:08x} ebx=0x{ebx:08x} ecx=0x{ecx:08x} edx=0x{edx:08x} ascii={raw_ascii!r}")
    except Exception as e:
        print(f"leaf=0x{leaf:08x} err={e}")
os.close(fd)
EOF
sudo tune2fs -l /dev/vdb > "$OUT_DIR/vdb_tune2fs.txt" 2>&1 || true
sudo head -c 2048 /dev/vda | od -tx1 -Ax > "$OUT_DIR/vda_superblock.hex" 2>&1 || true
ip -d addr > "$OUT_DIR/ip_addr.txt"
curl -sS --max-time 5 https://ipinfo.io/json > "$OUT_DIR/egress_ipinfo.json" 2>/dev/null || true
(cd "$OUT_DIR" && sha256sum * > SHA256SUMS.txt)
