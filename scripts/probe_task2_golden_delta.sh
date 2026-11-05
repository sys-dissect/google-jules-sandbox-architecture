#!/usr/bin/env bash
# ==============================================================================
# probe_task2_golden_delta.sh
# Tier-1 Telemetry: Golden Image Baseline, Persistence Deltas & Package State
# ==============================================================================
# Usage:
#   ./scripts/probe_task2_golden_delta.sh [OUTPUT_DIR]
# Example:
#   ./scripts/probe_task2_golden_delta.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_OUT_DIR="${REPO_ROOT}/evidence/raw/golden_delta"
OUT_DIR="${1:-${DEFAULT_OUT_DIR}}"

echo "=============================================================================="
echo " [TIER-1 PROBE] Task 2 Golden Image Delta & Audit Telemetry"
echo " Target Output Directory: ${OUT_DIR}"
echo " Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "=============================================================================="

mkdir -p "${OUT_DIR}"

# 1. Early Boot Journal in JSON format
echo "[1/8] Capturing early boot journal entries in JSON format..."
sudo journalctl -b 0 -o json --no-pager > "${OUT_DIR}/early_boot_journal.json" 2>/dev/null || \
journalctl -b 0 -o json --no-pager > "${OUT_DIR}/early_boot_journal.json" 2>/dev/null || \
journalctl -o json --no-pager > "${OUT_DIR}/early_boot_journal.json" 2>/dev/null || \
echo '{"error": "journalctl unavailable or empty"}' > "${OUT_DIR}/early_boot_journal.json"

# 2. Base Image /dev/vda SHA256 Hash
echo "[2/8] Hashing immutable base disk /dev/vda (SquashFS 4.0)..."
if [ -b /dev/vda ]; then
    sudo sha256sum /dev/vda > "${OUT_DIR}/vda_sha256.txt" 2>/dev/null || \
    echo "Error computing sha256sum of /dev/vda" > "${OUT_DIR}/vda_sha256.txt"
else
    echo "/dev/vda block device not found on this host" > "${OUT_DIR}/vda_sha256.txt"
fi

# 3. Block Device Identifiers (blkid)
echo "[3/8] Capturing block device UUIDs and filesystem signatures via blkid..."
sudo blkid > "${OUT_DIR}/blkid.txt" 2>/dev/null || blkid > "${OUT_DIR}/blkid.txt" 2>/dev/null || echo "blkid unavailable" > "${OUT_DIR}/blkid.txt"

# 4. Active LSMs from securityfs / sysfs
echo "[4/8] Probing active Linux Security Modules (securityfs / sysfs)..."
{
    echo "=== ACTIVE LSMs (securityfs / sysfs) ==="
    if [ -f /sys/kernel/security/lsm ]; then
        echo -n "LSM sysfs (/sys/kernel/security/lsm): "
        cat /sys/kernel/security/lsm 2>/dev/null || echo "UNREADABLE"
        echo ""
    else
        echo "LSM sysfs entry not present (/sys/kernel/security/lsm missing or securityfs unmounted)"
    fi

    if [ -d /sys/kernel/security ]; then
        echo "=== /sys/kernel/security directory listing ==="
        ls -la /sys/kernel/security/ 2>/dev/null || echo "Unable to list /sys/kernel/security"
    fi

    echo "=== Kernel Command Line Security Flags ==="
    grep -oE '(apparmor|selinux|lsm|security)=[^\ ]+' /proc/cmdline 2>/dev/null || echo "No security module flags in /proc/cmdline"
} > "${OUT_DIR}/active_lsms.txt"

# 5. Fixed SUID/SGID Scan with -xdev
echo "[5/8] Scanning root and scratch filesystems for SUID/SGID binaries (-xdev)..."
{
    echo "=== SUID / SGID Files on Root Filesystem (find / -xdev) ==="
    sudo find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -exec ls -la {} + 2>/dev/null || true

    if mountpoint -q /rom/overlay 2>/dev/null || [ -d /rom/overlay ]; then
        echo ""
        echo "=== SUID / SGID Files on Underlying Scratch (find /rom/overlay -xdev) ==="
        sudo find /rom/overlay -xdev \( -perm -4000 -o -perm -2000 \) -type f -exec ls -la {} + 2>/dev/null || true
    fi
} > "${OUT_DIR}/suid_sgid.txt"

# 6. Systemd Units, Shell Init & Profiles Tarball
echo "[6/8] Archiving systemd service definitions, shell init scripts, and profile configurations..."
TAR_TARGETS=()
for path in \
    /etc/systemd/system \
    /etc/profile \
    /etc/profile.d \
    /etc/bash.bashrc \
    /etc/environment \
    /home/jules/.bashrc \
    /home/jules/.profile \
    /home/jules/.bash_profile \
    /root/.bashrc \
    /root/.profile; do
    if [ -e "$path" ]; then
        TAR_TARGETS+=("$path")
    fi
done

if [ ${#TAR_TARGETS[@]} -gt 0 ]; then
    sudo tar -czf "${OUT_DIR}/system_units_and_profiles.tar.gz" "${TAR_TARGETS[@]}" 2>/dev/null || \
    echo "Warning: tar creation had non-zero exit"
else
    echo "No target configuration files found to archive" > "${OUT_DIR}/system_units_and_profiles_empty.txt"
fi

# 7. /opt, /usr/local, and devbox Directory Listings
echo "[7/8] Generating recursive file manifests for /opt, /usr/local, and /run/devbox-session..."
{
    echo "=== /opt Manifest ==="
    ls -laR /opt 2>/dev/null || echo "/opt not found"
    echo ""
    echo "=== /usr/local Manifest ==="
    ls -laR /usr/local 2>/dev/null || echo "/usr/local not found"
    echo ""
    echo "=== /run/devbox-session Manifest ==="
    ls -laR /run/devbox-session 2>/dev/null || echo "/run/devbox-session not found"
} > "${OUT_DIR}/opt_usrlocal_devbox_listing.txt"

# 8. Unowned Dpkg Files
echo "[8/8] Cross-referencing filesystem against package database for unowned files..."
{
    echo "=== Scanning for Files Not Tracked by dpkg ==="
    TMP_DPKG=$(mktemp)
    TMP_SYS=$(mktemp)
    if compgen -G "/var/lib/dpkg/info/*.list" > /dev/null; then
        (cat /var/lib/dpkg/info/*.list 2>/dev/null | sed 's/ -> .*//' | sort -u > "$TMP_DPKG") || true
        # Audit critical binaries, libraries, configs, and application roots
        (sudo find /bin /sbin /usr/bin /usr/sbin /etc /opt /usr/local -xdev \( -type f -o -type l \) 2>/dev/null | sort -u > "$TMP_SYS") || true
        comm -23 "$TMP_SYS" "$TMP_DPKG" || true
        rm -f "$TMP_DPKG" "$TMP_SYS"
    else
        echo "dpkg database (/var/lib/dpkg/info/*.list) not accessible on this system"
        rm -f "$TMP_DPKG" "$TMP_SYS"
    fi
} > "${OUT_DIR}/unowned_dpkg_files.txt"

# Checksum Manifest
echo "[*] Generating SHA256SUMS.txt manifest..."
(
    cd "${OUT_DIR}"
    rm -f SHA256SUMS.txt
    sha256sum * > SHA256SUMS.txt 2>/dev/null || true
) || true

echo "=============================================================================="
echo " [TIER-1 PROBE COMPLETE] Task 2 Golden Delta Evidence Captured in:"
echo " ${OUT_DIR}"
echo "=============================================================================="
