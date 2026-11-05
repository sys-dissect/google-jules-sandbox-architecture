#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-start}"
LOG="/tmp/task3_counter.jsonl"
PIDFILE="/tmp/task3_counter.pid"
if [ "$MODE" = "start" ]; then
    nohup python3 - "$LOG" << 'EOF' >/dev/null 2>&1 &
import json, sys, time
log_path = sys.argv[1]
seq = 0
with open(log_path, "a", buffering=1) as f:
    while True:
        seq += 1
        try:
            entropy = open("/proc/sys/kernel/random/entropy_avail").read().strip()
        except Exception:
            entropy = "-1"
        rec = {
            "seq": seq,
            "wall_s": time.time(),
            "mono_s": time.monotonic(),
            "boot_id": open("/proc/sys/kernel/random/boot_id").read().strip(),
            "entropy": int(entropy)
        }
        f.write(json.dumps(rec) + "\n")
        time.sleep(1.0)
EOF
    echo $! > "$PIDFILE"
    sleep 2
    echo "started_pid=$(cat "$PIDFILE")"
else
    TS="$(date -u +%Y%m%dT%H%M%SZ)"
    OUT_DIR="evidence/raw/task3_resume_${TS}"
    mkdir -p "$OUT_DIR"
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "status=alive pid=$(cat "$PIDFILE")" > "$OUT_DIR/status.txt"
    else
        echo "status=dead" > "$OUT_DIR/status.txt"
    fi
    cp "$LOG" "$OUT_DIR/counter.jsonl" 2>/dev/null || true
    sudo dmesg -T | grep -iE "crng|random|clock|time|kvm" > "$OUT_DIR/dmesg_clock_rng.txt" 2>&1 || true
    (cd "$OUT_DIR" && sha256sum * > SHA256SUMS.txt)
fi
