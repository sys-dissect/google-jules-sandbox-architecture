#!/usr/bin/env bash
set -euo pipefail
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="evidence/raw/task9_10_git_setup_${TS}"
mkdir -p "$OUT_DIR"
# Git clone provenance, reflog timestamps, and stat birth times
stat /app /app/.git /app/.git/HEAD /app/.git/index /app/.git/config > "$OUT_DIR/app_git_stat.txt" 2>&1 || true
git config --list --show-origin > "$OUT_DIR/git_config_origins.txt" 2>&1 || true
git reflog --date=iso-strict > "$OUT_DIR/git_reflog_iso.txt" 2>&1 || true
ls -la --time-style=full-iso /app/.git /app/.git/logs /app/.git/refs/remotes/origin > "$OUT_DIR/git_dir_timestamps.txt" 2>&1 || true
env | sort > "$OUT_DIR/swebot_env.txt"
# Capture live wire exchange against 192.168.0.1:8080 during git ls-remote
sudo tcpdump -i any -s 0 -w "$OUT_DIR/git_proxy_lsremote.pcap" host 192.168.0.1 and port 8080 >/dev/null 2>&1 &
TCPDUMP_PID=$!
sleep 1
git ls-remote origin > "$OUT_DIR/git_ls_remote.txt" 2>&1 || true
sleep 1
sudo kill "$TCPDUMP_PID" 2>/dev/null || true
# Check setup script execution traces in journal and /run
sudo journalctl -o json --boot > "$OUT_DIR/journal_boot.json" 2>&1 || true
sudo find /run /tmp /var/log -maxdepth 3 -ls > "$OUT_DIR/run_tmp_varlog_ls.txt" 2>&1 || true
(cd "$OUT_DIR" && sha256sum * > SHA256SUMS.txt)
