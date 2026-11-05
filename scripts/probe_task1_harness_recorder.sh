#!/usr/bin/env bash
set -euo pipefail
OUT_DIR="/tmp/task1_capture"
mkdir -p "$OUT_DIR/session_files" "$OUT_DIR/strace"
sudo cp -a /run/devbox-session "$OUT_DIR/initial_devbox_session" 2>/dev/null || true
for pid in $(pgrep -f "sshd|tmux|devbox|bash" || true); do
    sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' > "$OUT_DIR/proc_${pid}_cmdline.txt" || true
    sudo cat "/proc/$pid/environ" 2>/dev/null | tr '\0' '\n' > "$OUT_DIR/proc_${pid}_environ.txt" || true
done
sudo nohup python3 - "$OUT_DIR/session_files" << 'EOF' >/dev/null 2>&1 &
import os, shutil, sys, time
out_dir = sys.argv[1]
watch_dir = "/run/devbox-session/default"
seen = {}
seq = 0
while True:
    try:
        for root, _, files in os.walk(watch_dir):
            for f in files:
                p = os.path.join(root, f)
                try:
                    st = os.stat(p)
                    sig = (st.st_mtime_ns, st.st_size)
                    if seen.get(p) != sig:
                        seen[p] = sig
                        seq += 1
                        shutil.copy2(p, os.path.join(out_dir, f"{seq:05d}_{int(time.time()*1000)}_{f}"))
                except FileNotFoundError:
                    pass
    except Exception:
        pass
    time.sleep(0.005)
EOF
echo $! > "$OUT_DIR/watcher.pid"
for pid in $(pgrep -f "tmux|sshd: swebot" || true); do
    sudo nohup strace -f -tt -s 16384 -e trace=execve,openat,read,write,rename,unlinkat,connect,accept4 \
      -o "$OUT_DIR/strace/trace_${pid}.log" -p "$pid" >/dev/null 2>&1 &
done
