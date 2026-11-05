#!/usr/bin/env bash
# ==============================================================================
# probe_task1_harness_recorder.sh
# Tier-1 Telemetry: Devbox Session IPC Harness Watcher & Execution Tracer
# ==============================================================================
# Usage:
#   ./scripts/probe_task1_harness_recorder.sh [DURATION_SECONDS] [OUTPUT_DIR]
# Examples:
#   ./scripts/probe_task1_harness_recorder.sh 60
#   ./scripts/probe_task1_harness_recorder.sh 0       # Run until Ctrl+C (SIGINT)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_OUT_DIR="${REPO_ROOT}/evidence/raw/harness_recorder"

DURATION=60
OUT_DIR="${DEFAULT_OUT_DIR}"

if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    DURATION="$1"
    if [ -n "${2:-}" ]; then OUT_DIR="$2"; fi
elif [ -n "${1:-}" ]; then
    OUT_DIR="$1"
    if [[ "${2:-}" =~ ^[0-9]+$ ]]; then DURATION="$2"; fi
fi

SESSION_DIR="/run/devbox-session/default"
WATCHER_PID=""
STRACE_PIDS=()

echo "=============================================================================="
echo " [TIER-1 PROBE] Task 1 Harness Recorder & Process Execution Tracer"
echo " Target Output Directory: ${OUT_DIR}"
echo " Harness Path:            ${SESSION_DIR}"
echo " Duration:                $([ "$DURATION" -eq 0 ] && echo "Indefinite (until SIGINT/Ctrl+C)" || echo "${DURATION} seconds")"
echo " Timestamp:               $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "=============================================================================="

mkdir -p "${OUT_DIR}"

# ------------------------------------------------------------------------------
# 1. Snapshot Initial devbox-session State & Listing
# ------------------------------------------------------------------------------
echo "[1/4] Snapshotting initial /run/devbox-session state and file trees..."
if [ -d /run/devbox-session ]; then
    sudo cp -a /run/devbox-session "${OUT_DIR}/initial_devbox_session" 2>/dev/null || true
    ls -laR /run/devbox-session > "${OUT_DIR}/initial_devbox_session_listing.txt" 2>/dev/null || true
else
    echo "/run/devbox-session does not exist at probe start" > "${OUT_DIR}/initial_devbox_session_listing.txt"
fi

# ------------------------------------------------------------------------------
# 2. Snapshot Process Trees & Environment Variables
# ------------------------------------------------------------------------------
echo "[2/4] Snapshotting process tree and process environments (/proc/[pid]/environ)..."
{
    echo "=== INITIAL PROCESS TREE ==="
    pstree -apug 2>/dev/null || ps auxf 2>/dev/null || true
} > "${OUT_DIR}/initial_pstree.txt"

{
    echo "=== INITIAL PROCESS ENVIRONMENTS (Sorted per PID) ==="
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    for p in /proc/[0-9]*; do
        if [ -d "$p" ]; then
            pid=$(basename "$p")
            if [ -f "$p/cmdline" ]; then
                cmd=$(cat "$p/cmdline" 2>/dev/null | tr '\0' ' ' || true)
                if [ -n "$cmd" ]; then
                    user=$(ps -o user= -p "$pid" 2>/dev/null || echo "unknown")
                    echo "=============================================================================="
                    echo "PID: ${pid} | USER: ${user} | CMD: ${cmd}"
                    echo "------------------------------------------------------------------------------"
                    env_content=$(cat "$p/environ" 2>/dev/null | tr '\0' '\n' | sort || true)
                    if [ -n "$env_content" ]; then
                        echo "$env_content"
                    else
                        echo "  [environ unreadable or empty]"
                    fi
                    echo ""
                fi
            fi
        fi
    done
} > "${OUT_DIR}/initial_process_environments.txt"

# ------------------------------------------------------------------------------
# 3. Launch High-Frequency Python Watcher on /run/devbox-session/default
# ------------------------------------------------------------------------------
echo "[3/4] Launching high-frequency (50Hz) Python watcher on ${SESSION_DIR}..."

python3 -c "
import os, sys, time, json, stat, signal
from datetime import datetime, timezone

target_dir = '${SESSION_DIR}'
out_jsonl = os.path.join('${OUT_DIR}', 'watcher_events.jsonl')
out_log = os.path.join('${OUT_DIR}', 'watcher_events.log')

keep_running = True
def handle_sig(sig, frame):
    global keep_running
    keep_running = False

signal.signal(signal.SIGINT, handle_sig)
signal.signal(signal.SIGTERM, handle_sig)

file_states = {}
file_offsets = {}

with open(out_log, 'a', encoding='utf-8') as log_f, open(out_jsonl, 'a', encoding='utf-8') as jsonl_f:
    log_f.write(f'=== Watcher started on {target_dir} at {datetime.now(timezone.utc).isoformat()} ===\n')
    log_f.flush()

    while keep_running:
        now = time.time()
        iso = datetime.now(timezone.utc).isoformat()
        if not os.path.exists(target_dir):
            time.sleep(0.05)
            continue

        try:
            entries = os.listdir(target_dir)
        except Exception:
            entries = []

        seen = set(entries)
        for name in entries:
            full_path = os.path.join(target_dir, name)
            try:
                st = os.stat(full_path)
            except Exception:
                continue

            is_reg = stat.S_ISREG(st.st_mode)
            is_fifo = stat.S_ISFIFO(st.st_mode)
            old = file_states.get(name)

            if old is None:
                content = None
                if is_reg and st.st_size < 65536:
                    try:
                        with open(full_path, 'r', encoding='utf-8', errors='replace') as rf:
                            content = rf.read()
                    except Exception:
                        pass
                event = {
                    'ts': now,
                    'iso': iso,
                    'event': 'CREATE',
                    'file': name,
                    'size': st.st_size,
                    'is_fifo': is_fifo,
                    'content': content
                }
                jsonl_f.write(json.dumps(event) + '\n')
                jsonl_f.flush()
                log_f.write(f'[{iso}] CREATE {name} (size={st.st_size})\n')
                log_f.flush()

                file_states[name] = {'size': st.st_size, 'mtime': st.st_mtime, 'is_reg': is_reg}
                file_offsets[name] = st.st_size

            elif old['size'] != st.st_size or old['mtime'] != st.st_mtime:
                delta = None
                if is_reg:
                    try:
                        with open(full_path, 'r', encoding='utf-8', errors='replace') as rf:
                            rf.seek(min(file_offsets.get(name, 0), st.st_size))
                            delta = rf.read()
                    except Exception:
                        pass
                event = {
                    'ts': now,
                    'iso': iso,
                    'event': 'MODIFY',
                    'file': name,
                    'old_size': old['size'],
                    'new_size': st.st_size,
                    'delta': delta
                }
                jsonl_f.write(json.dumps(event) + '\n')
                jsonl_f.flush()
                log_f.write(f'[{iso}] MODIFY {name} ({old[\"size\"]} -> {st.st_size} bytes)\n')
                if delta:
                    log_f.write(f'    Delta: {repr(delta[:200])}\n')
                log_f.flush()

                file_states[name] = {'size': st.st_size, 'mtime': st.st_mtime, 'is_reg': is_reg}
                file_offsets[name] = st.st_size

        for name in list(file_states.keys()):
            if name not in seen:
                event = {'ts': now, 'iso': iso, 'event': 'DELETE', 'file': name}
                jsonl_f.write(json.dumps(event) + '\n')
                jsonl_f.flush()
                log_f.write(f'[{iso}] DELETE {name}\n')
                log_f.flush()
                del file_states[name]
                if name in file_offsets:
                    del file_offsets[name]

        time.sleep(0.02)

    log_f.write(f'=== Watcher stopped at {datetime.now(timezone.utc).isoformat()} ===\n')
    log_f.flush()
" &
WATCHER_PID=$!
echo "  Python watcher running in background (PID: ${WATCHER_PID})"

# ------------------------------------------------------------------------------
# 4. Attach strace to tmux and swebot sshd processes
# ------------------------------------------------------------------------------
echo "[4/4] Locating tmux and swebot sshd processes for strace attachment..."
{
    echo "=== STRACE ATTACHMENT REPORT ==="
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} > "${OUT_DIR}/strace_attached_processes.txt"

if command -v strace >/dev/null 2>&1; then
    # Locate tmux processes
    TMUX_PIDS=$(pgrep -f "tmux" || true)
    if [ -n "${TMUX_PIDS}" ]; then
        for t_pid in ${TMUX_PIDS}; do
            cmd=$(ps -o cmd= -p "${t_pid}" 2>/dev/null || echo "tmux")
            echo "  Attaching strace to tmux PID ${t_pid}: ${cmd}"
            echo "tmux PID ${t_pid}: ${cmd}" >> "${OUT_DIR}/strace_attached_processes.txt"
            sudo strace -ff -tt -T -s 1024 -o "${OUT_DIR}/strace_tmux_${t_pid}.log" -p "${t_pid}" 2>/dev/null &
            STRACE_PIDS+=($!)
        done
    else
        echo "  Notice: No active tmux processes found"
        echo "No active tmux processes found at start" >> "${OUT_DIR}/strace_attached_processes.txt"
    fi

    # Locate swebot sshd processes
    SSHD_PIDS=$(pgrep -f "sshd: swebot" || true)
    if [ -n "${SSHD_PIDS}" ]; then
        for s_pid in ${SSHD_PIDS}; do
            cmd=$(ps -o cmd= -p "${s_pid}" 2>/dev/null || echo "sshd: swebot")
            echo "  Attaching strace to swebot sshd PID ${s_pid}: ${cmd}"
            echo "sshd swebot PID ${s_pid}: ${cmd}" >> "${OUT_DIR}/strace_attached_processes.txt"
            sudo strace -ff -tt -T -s 1024 -o "${OUT_DIR}/strace_sshd_${s_pid}.log" -p "${s_pid}" 2>/dev/null &
            STRACE_PIDS+=($!)
        done
    else
        echo "  Notice: No active 'sshd: swebot' processes found"
        echo "No active 'sshd: swebot' processes found at start" >> "${OUT_DIR}/strace_attached_processes.txt"
    fi
else
    echo "  WARNING: strace is not installed. To trace syscalls: sudo apt-get install -y strace"
    echo "strace binary not found" >> "${OUT_DIR}/strace_attached_processes.txt"
fi

# ------------------------------------------------------------------------------
# Cleanup Routine (Runs on exit, timeout, or SIGINT/SIGTERM)
# ------------------------------------------------------------------------------
cleanup() {
    set +e
    echo ""
    echo "[*] Stopping strace attachments..."
    if [ ${#STRACE_PIDS[@]} -gt 0 ]; then
        for spid in "${STRACE_PIDS[@]}"; do
            if [ -n "$spid" ]; then
                sudo kill -TERM "$spid" 2>/dev/null || true
            fi
        done
    fi

    echo "[*] Stopping Python watcher (PID: ${WATCHER_PID})..."
    if [ -n "${WATCHER_PID}" ]; then
        kill -TERM "${WATCHER_PID}" 2>/dev/null || true
        wait "${WATCHER_PID}" 2>/dev/null || true
    fi

    echo "[*] Capturing final /run/devbox-session state and process tree..."
    if [ -d /run/devbox-session ]; then
        sudo cp -a /run/devbox-session "${OUT_DIR}/final_devbox_session" 2>/dev/null || true
        ls -laR /run/devbox-session > "${OUT_DIR}/final_devbox_session_listing.txt" 2>/dev/null || true
    fi
    pstree -apug > "${OUT_DIR}/final_pstree.txt" 2>/dev/null || ps auxf > "${OUT_DIR}/final_ps.txt" 2>/dev/null || true

    echo "[*] Generating SHA256SUMS.txt manifest..."
    (
        cd "${OUT_DIR}"
        rm -f SHA256SUMS.txt
        sha256sum * > SHA256SUMS.txt 2>/dev/null || true
    ) || true

    echo "=============================================================================="
    echo " [TIER-1 PROBE COMPLETE] Harness Recording Finalized in:"
    echo " ${OUT_DIR}"
    echo "=============================================================================="
}

trap cleanup EXIT INT TERM

# ------------------------------------------------------------------------------
# Execution Loop
# ------------------------------------------------------------------------------
if [ "${DURATION}" -gt 0 ]; then
    echo "[*] Recording for ${DURATION} seconds (press Ctrl+C to stop earlier)..."
    sleep "${DURATION}"
else
    echo "[*] Recording continuously. Press Ctrl+C to terminate and finalize evidence..."
    while true; do
        sleep 1
    done
fi
