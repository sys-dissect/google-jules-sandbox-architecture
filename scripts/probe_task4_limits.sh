#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-standard}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="evidence/raw/task4_limits_${MODE}_${TS}"
mkdir -p "$OUT_DIR"
cat /proc/meminfo > "$OUT_DIR/meminfo_before.txt"
swapon --show > "$OUT_DIR/swap.txt" 2>&1 || true
# 1. CPU steal & throttling check (30s all-core load)
python3 - << 'EOF' > "$OUT_DIR/cpu_steal_series.jsonl" &
import json, os, time
end = time.time() + 32
while time.time() < end:
    with open("/proc/stat") as f:
        cpu_line = f.readline().split()
    print(json.dumps({"ts": time.time(), "cpu": cpu_line}), flush=True)
    time.sleep(1.0)
EOF
MON_PID=$!
NPROC="$(nproc)"
for _ in $(seq 1 "$NPROC"); do
    python3 -c 'import time; t=time.time()+30; 
while time.time()<t: _=999999*999999' &
done
wait "$MON_PID" || true
wait || true
# 2. Disk I/O burst vs plateau (60s sequential & random write/read via python direct/sync I/O or dd timeseries)
python3 - "$OUT_DIR/disk_io_series.jsonl" << 'EOF'
import json, os, time, sys
out = sys.argv[1]
buf = os.urandom(4 * 1024 * 1024)
fd = os.open("/tmp/io_probe.bin", os.O_CREAT | os.O_WRONLY | os.O_SYNC, 0o600)
start = time.time()
with open(out, "w", buffering=1) as log:
    while time.time() - start < 45:
        t0 = time.time()
        written = 0
        while time.time() - t0 < 1.0:
            os.write(fd, buf)
            written += len(buf)
            if written > 512 * 1024 * 1024:
                os.lseek(fd, 0, os.SEEK_SET)
        log.write(json.dumps({"elapsed_s": round(time.time() - start, 2), "bytes_per_sec": written}) + "\n")
os.close(fd)
os.unlink("/tmp/io_probe.bin")
EOF
# 3. Network download burst vs plateau
curl -sS -w "speed_download=%{speed_download} time_total=%{time_total} size_download=%{size_download}\n" \
  -o /dev/null https://speed.cloudflare.com/__down?bytes=250000000 > "$OUT_DIR/net_burst_250mb.txt" 2>&1 || true
# 4. Optional OOM probe (only when called with 'oom')
if [ "$MODE" = "oom" ]; then
    python3 - "$OUT_DIR/oom_ladder.txt" << 'EOF' || true
import sys, time
log = open(sys.argv[1], "w", buffering=1)
chunks = []
step_mb = 128
try:
    while True:
        chunks.append(bytearray(step_mb * 1024 * 1024))
        log.write(f"ts={time.time()} allocated_mb={len(chunks)*step_mb}\n")
        time.sleep(0.2)
except MemoryError as e:
    log.write(f"MemoryError: {e}\n")
EOF
    sudo dmesg -T | tail -n 100 > "$OUT_DIR/dmesg_post_oom.txt" 2>&1 || true
fi
(cd "$OUT_DIR" && sha256sum * > SHA256SUMS.txt)
