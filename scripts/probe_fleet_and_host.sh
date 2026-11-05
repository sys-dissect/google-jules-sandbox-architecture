#!/usr/bin/env bash
# ==============================================================================
# probe_fleet_and_host.sh
# Tier-1 Telemetry: Fleet Identification, Host Topology & Hypervisor Profiling
# ==============================================================================
# Usage:
#   ./scripts/probe_fleet_and_host.sh [OUTPUT_DIR]
# Example:
#   ./scripts/probe_fleet_and_host.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_OUT_DIR="${REPO_ROOT}/evidence/raw/fleet_and_host"
OUT_DIR="${1:-${DEFAULT_OUT_DIR}}"

echo "=============================================================================="
echo " [TIER-1 PROBE] Fleet & Host Telemetry Collector"
echo " Target Output Directory: ${OUT_DIR}"
echo " Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "=============================================================================="

mkdir -p "${OUT_DIR}"

# 1. Boot ID
echo "[1/11] Collecting kernel boot ID..."
if [ -r /proc/sys/kernel/random/boot_id ]; then
    cat /proc/sys/kernel/random/boot_id > "${OUT_DIR}/boot_id.txt" || echo "ERROR" > "${OUT_DIR}/boot_id.txt"
else
    echo "UNAVAILABLE" > "${OUT_DIR}/boot_id.txt"
fi

# 2. Uptime
echo "[2/11] Collecting system uptime and kernel freshness..."
{
    echo "=== /proc/uptime ==="
    cat /proc/uptime 2>/dev/null || echo "N/A"
    echo ""
    echo "=== uptime ==="
    uptime 2>/dev/null || echo "N/A"
    echo ""
    echo "=== uptime -s (boot timestamp) ==="
    uptime -s 2>/dev/null || echo "N/A"
} > "${OUT_DIR}/uptime.txt"

# 3. CPU Info
echo "[3/11] Collecting /proc/cpuinfo..."
cat /proc/cpuinfo > "${OUT_DIR}/cpuinfo.txt" 2>/dev/null || echo "Error reading /proc/cpuinfo" > "${OUT_DIR}/cpuinfo.txt"

# 4. CPU Vulnerabilities
echo "[4/11] Collecting kernel CPU vulnerability mitigations..."
{
    echo "=== CPU VULNERABILITIES (/sys/devices/system/cpu/vulnerabilities/) ==="
    if compgen -G "/sys/devices/system/cpu/vulnerabilities/*" > /dev/null; then
        for v in /sys/devices/system/cpu/vulnerabilities/*; do
            if [ -f "$v" ]; then
                echo -n "$(basename "$v"): "
                cat "$v" 2>/dev/null || echo "UNREADABLE"
            fi
        done
    else
        echo "No /sys/devices/system/cpu/vulnerabilities/ directory exposed by kernel"
    fi
} > "${OUT_DIR}/cpu_vulnerabilities.txt"

# 5. Cache Topology
echo "[5/11] Inspecting hardware cache topology..."
{
    echo "=== CPU CACHE TOPOLOGY (/sys/devices/system/cpu/cpu*/cache/) ==="
    if compgen -G "/sys/devices/system/cpu/cpu[0-9]*/cache/index*" > /dev/null; then
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
            cname=$(basename "$cpu")
            if [ -d "$cpu/cache" ]; then
                echo "--- $cname Cache ---"
                for idx in "$cpu"/cache/index*; do
                    if [ -d "$idx" ]; then
                        iname=$(basename "$idx")
                        lvl=$(cat "$idx/level" 2>/dev/null || echo "?")
                        type=$(cat "$idx/type" 2>/dev/null || echo "?")
                        size=$(cat "$idx/size" 2>/dev/null || echo "?")
                        ways=$(cat "$idx/ways_of_associativity" 2>/dev/null || echo "?")
                        linesize=$(cat "$idx/coherency_line_size" 2>/dev/null || echo "?")
                        shared=$(cat "$idx/shared_cpu_list" 2>/dev/null || echo "?")
                        echo "  ${iname}: Level=${lvl} Type=${type} Size=${size} Ways=${ways} LineSize=${linesize} SharedCPUs=${shared}"
                    fi
                done
            fi
        done
    else
        echo "No cache hierarchy sysfs entries exposed by hypervisor"
    fi
} > "${OUT_DIR}/cache_topology.txt"

# 6. Clocksource
echo "[6/11] Collecting clocksource configuration..."
{
    echo "=== CLOCKSOURCE TELEMETRY (/sys/devices/system/clocksource/clocksource0/) ==="
    if compgen -G "/sys/devices/system/clocksource/clocksource*/*" > /dev/null; then
        for cs in /sys/devices/system/clocksource/clocksource*/*; do
            if [ -f "$cs" ]; then
                echo "$(basename "$cs"): $(cat "$cs" 2>/dev/null || echo "UNREADABLE")"
            fi
        done
    else
        echo "No clocksource sysfs entries found"
    fi
} > "${OUT_DIR}/clocksource.txt"

# 7. CPUID Hypervisor Leaves
echo "[7/11] Reading CPUID hypervisor leaves via python3 on /dev/cpu/0/cpuid..."
# Create char device if missing in guest devtmpfs
if [ ! -c /dev/cpu/0/cpuid ]; then
    sudo mkdir -p /dev/cpu/0 2>/dev/null || true
    sudo mknod /dev/cpu/0/cpuid c 203 0 2>/dev/null || true
    sudo chmod 0444 /dev/cpu/0/cpuid 2>/dev/null || true
fi

(sudo python3 -c '
import os, struct, sys

out = []
cpuid_path = "/dev/cpu/0/cpuid"
out.append("=== CPUID HYPERVISOR LEAF TELEMETRY ===")

try:
    fd = os.open(cpuid_path, os.O_RDONLY)
    out.append(f"Successfully opened {cpuid_path}")

    # Leaf 0x40000000 is the standard base hypervisor signature leaf
    for leaf in range(0x40000000, 0x40000020):
        try:
            data = os.pread(fd, 16, leaf)
            if len(data) == 16:
                eax, ebx, ecx, edx = struct.unpack("<IIII", data)
                sig_bytes = struct.pack("<III", ebx, ecx, edx)
                sig_str = "".join(chr(b) if 32 <= b <= 126 else "." for b in sig_bytes).strip()
                out.append(f"Leaf 0x{leaf:08x}: EAX=0x{eax:08x} EBX=0x{ebx:08x} ECX=0x{ecx:08x} EDX=0x{edx:08x} | Sig: {sig_str}")
                if leaf == 0x40000000 and (eax < 0x40000000 or eax > 0x40000100):
                    out.append(f"  Note: Leaf 0x40000000 indicates max hypervisor leaf 0x{eax:08x}")
                    if eax == 0:
                        break
        except Exception as e:
            out.append(f"Leaf 0x{leaf:08x}: Read error: {e}")
    os.close(fd)
except Exception as e:
    out.append(f"Unable to read {cpuid_path}: {e}")
    out.append("Fallback: checking hypervisor flags in /proc/cpuinfo:")
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("flags"):
                    flags = line.split(":", 1)[1].strip().split()
                    hv_flags = [fl for fl in flags if "hypervisor" in fl]
                    out.append(f"  Hypervisor flags in cpuinfo: {hv_flags}")
                    break
    except Exception as e2:
        out.append(f"  /proc/cpuinfo fallback error: {e2}")

sys.stdout.write("\n".join(out) + "\n")
' 2>&1 || python3 -c '
import sys
try:
    with open("/proc/cpuinfo") as f:
        for line in f:
            if line.startswith("flags"):
                flags = line.split(":", 1)[1].strip().split()
                hv_flags = [fl for fl in flags if "hypervisor" in fl]
                print(f"Fallback Hypervisor flags in cpuinfo: {hv_flags}")
                break
except Exception as e:
    print(f"Fallback check failed: {e}")
' 2>&1 || echo "CPUID hypervisor probe failed") > "${OUT_DIR}/cpuid_hypervisor_leaves.txt" || true

# 8. vdb tune2fs
echo "[8/11] Auditing /dev/vdb ext4 superblock geometry via tune2fs..."
if [ -b /dev/vdb ]; then
    if command -v tune2fs >/dev/null 2>&1; then
        sudo tune2fs -l /dev/vdb > "${OUT_DIR}/vdb_tune2fs.txt" 2>/dev/null || echo "tune2fs /dev/vdb failed" > "${OUT_DIR}/vdb_tune2fs.txt"
    else
        echo "tune2fs utility not found" > "${OUT_DIR}/vdb_tune2fs.txt"
    fi
else
    echo "/dev/vdb block device not present on this host" > "${OUT_DIR}/vdb_tune2fs.txt"
fi

# 9. vda Superblock Hex Dump
echo "[9/11] Capturing /dev/vda SquashFS superblock hex dump..."
{
    echo "=== /dev/vda Superblock Hex Dump (First 4096 bytes) ==="
    if [ -b /dev/vda ]; then
        if command -v hexdump >/dev/null 2>&1; then
            (sudo dd if=/dev/vda bs=1k count=4 2>/dev/null || true) | (hexdump -C || true)
        elif command -v od >/dev/null 2>&1; then
            (sudo dd if=/dev/vda bs=1k count=4 2>/dev/null || true) | (od -Ax -tx1 -v || true)
        elif command -v xxd >/dev/null 2>&1; then
            (sudo dd if=/dev/vda bs=1k count=4 2>/dev/null || true) | (xxd || true)
        else
            sudo python3 -c '
import sys
try:
    with open("/dev/vda", "rb") as f:
        data = f.read(4096)
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_str = " ".join(f"{b:02x}" for b in chunk)
        asc_str = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
        print(f"{i:08x}  {hex_str:<48}  |{asc_str}|")
except Exception as e:
    print(f"Error reading /dev/vda: {e}")
' || true
        fi
    else
        echo "/dev/vda block device not present on this host"
    fi
} > "${OUT_DIR}/vda_superblock.hex" || true

# 10. IP Address & Route
echo "[10/11] Dumping network address and routing configuration..."
{
    echo "=== ip -d addr show ==="
    ip -d addr show 2>/dev/null || ip addr 2>/dev/null || true
    echo ""
    echo "=== ip link show ==="
    ip link show 2>/dev/null || true
    echo ""
    echo "=== ip route show ==="
    ip route show 2>/dev/null || true
} > "${OUT_DIR}/ip_addr.txt"

# 11. Egress IP Info
echo "[11/11] Probing public egress metadata via ipinfo.io..."
curl -s --connect-timeout 5 --max-time 10 https://ipinfo.io/json > "${OUT_DIR}/ipinfo.json" 2>/dev/null || {
    echo '{"error": "curl to ipinfo.io failed or timed out"}' > "${OUT_DIR}/ipinfo.json"
}

# Checksum Manifest
echo "[*] Generating SHA256SUMS.txt manifest..."
(
    cd "${OUT_DIR}"
    rm -f SHA256SUMS.txt
    sha256sum * > SHA256SUMS.txt 2>/dev/null || true
) || true

echo "=============================================================================="
echo " [TIER-1 PROBE COMPLETE] Fleet & Host Telemetry Captured in:"
echo " ${OUT_DIR}"
echo "=============================================================================="
