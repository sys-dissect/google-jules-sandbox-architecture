#!/usr/bin/env bash
set -euo pipefail
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="evidence/raw/task2_golden_delta_${TS}"
mkdir -p "$OUT_DIR"
sudo journalctl -o json --boot > "$OUT_DIR/journal_boot.json" 2>&1 || true
sudo sha256sum /dev/vda > "$OUT_DIR/vda_sha256.txt" 2>&1 || true
sudo blkid > "$OUT_DIR/blkid.txt" 2>&1 || true
sudo mount -t securityfs securityfs /sys/kernel/security 2>/dev/null || true
cat /sys/kernel/security/lsm > "$OUT_DIR/lsm_active.txt" 2>&1 || true
sudo find / -xdev \( -perm -4000 -o -perm -2000 \) -type f -exec ls -ld {} + > "$OUT_DIR/suid_sgid_xdev.txt" 2>&1 || true
sudo tar -czf "$OUT_DIR/etc_profile_and_systemd.tar.gz" \
  /etc/profile /etc/profile.d /etc/bash.bashrc /etc/environment \
  /etc/systemd/system /lib/systemd/system/devbox* \
  /home/swebot/.bashrc /home/swebot/.profile /root/.bashrc 2>/dev/null || true
sudo find /opt /usr/local /run/devbox-session -ls > "$OUT_DIR/opt_usrlocal_devbox_ls.txt" 2>&1 || true
sudo python3 - << 'EOF' > "$OUT_DIR/unowned_files.txt" 2>&1
import glob, os
owned = set()
for list_file in glob.glob("/var/lib/dpkg/info/*.list"):
    with open(list_file, "r", errors="replace") as f:
        for line in f:
            owned.add(line.strip())
skip_prefixes = ("/proc", "/sys", "/dev", "/run", "/tmp", "/var/lib/docker", "/var/lib/containerd", "/app", "/home")
for root, dirs, files in os.walk("/", topdown=True):
    dirs[:] = [d for d in dirs if not os.path.join(root, d).startswith(skip_prefixes)]
    for name in files:
        full = os.path.join(root, name)
        if full not in owned:
            print(full)
EOF
(cd "$OUT_DIR" && sha256sum * > SHA256SUMS.txt)
