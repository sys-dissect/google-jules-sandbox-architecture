#!/usr/bin/env bash
set -euo pipefail
LABEL="${1:-coding}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="evidence/raw/task1_${LABEL}_${TS}"
mkdir -p "$OUT_DIR"
sudo pkill -f "strace -f -tt" 2>/dev/null || true
if [ -f /tmp/task1_capture/watcher.pid ]; then
    sudo kill "$(cat /tmp/task1_capture/watcher.pid)" 2>/dev/null || true
fi
sudo cp -a /run/devbox-session "/tmp/task1_capture/final_devbox_session" 2>/dev/null || true
sudo tar -czf "$OUT_DIR/task1_capture.tar.gz" -C /tmp task1_capture
(cd "$OUT_DIR" && sha256sum * > SHA256SUMS.txt)
