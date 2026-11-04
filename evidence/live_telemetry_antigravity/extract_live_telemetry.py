#!/usr/bin/env python3
import subprocess
import os
import sys
import time

TC_ADDR = "tcpGFwWCB4kL-bJnV4SoYOQ7kx5p6Fwr1fczjV3EBEDgVW4XKUOGFrWCCePMPzAykMIn3xg_TiUlMQflCgBKIF2jBl82UgUrXHPGFxWCCx0fWODe6bTO4OTNqzCth_TPzKu76HodyJLjgv8LXsQmFpGQEt"
TAILCAT_BIN = "/home/onkar/.local/bin/tailcat"
BASE_DIR = "/home/onkar/Projects/google-jules-sandbox-architecture/evidence/live_telemetry_antigravity"

def run_remote_command(cmd, timeout=30):
    full_cmd = [TAILCAT_BIN, "ssh", f"root@{TC_ADDR}", cmd]
    try:
        res = subprocess.run(full_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
        return res.stdout, res.stderr, res.returncode
    except subprocess.TimeoutExpired:
        return "", "TIMEOUT", -1
    except Exception as e:
        return "", str(e), -1

def run_and_save(category, filename, remote_cmd, timeout=30, sudo=False):
    out_path = os.path.join(BASE_DIR, category, filename)
    cmd = f"sudo bash -c '{remote_cmd}'" if sudo else remote_cmd
    print(f"[*] [{category}] Harvesting: {filename} ... ", end="", flush=True)
    t0 = time.time()
    stdout, stderr, rc = run_remote_command(cmd, timeout=timeout)
    elapsed = time.time() - t0
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(stdout)
        if stderr and rc != 0:
            f.write(f"\n--- STDERR (rc={rc}) ---\n{stderr}")
    print(f"done ({elapsed:.1f}s, {len(stdout)} bytes, rc={rc})")

def main():
    print(f"=== Starting Jules Live Sandbox Telemetry Sweep ===")
    print(f"Target: {TC_ADDR[:25]}...")
    print(f"Output Base: {BASE_DIR}\n")

    # 1. Kernel, Hypervisor & ACPI
    run_and_save("kernel_and_hypervisor", "dmesg_full.txt", "dmesg", timeout=15, sudo=True)
    run_and_save("kernel_and_hypervisor", "cmdline.txt", "cat /proc/cmdline", timeout=10)
    run_and_save("kernel_and_hypervisor", "cpuinfo.txt", "cat /proc/cpuinfo", timeout=10)
    run_and_save("kernel_and_hypervisor", "iomem.txt", "cat /proc/iomem", timeout=10, sudo=True)
    run_and_save("kernel_and_hypervisor", "ioports.txt", "cat /proc/ioports", timeout=10, sudo=True)
    run_and_save("kernel_and_hypervisor", "interrupts.txt", "cat /proc/interrupts", timeout=10)
    run_and_save("kernel_and_hypervisor", "sysctl_all.txt", "sysctl -a 2>/dev/null", timeout=15, sudo=True)
    run_and_save("kernel_and_hypervisor", "clocksource.txt", "tail -n +1 /sys/devices/system/clocksource/clocksource0/* 2>/dev/null", timeout=10)
    run_and_save("kernel_and_hypervisor", "virtio_devices.txt", """
for d in /sys/bus/virtio/devices/*; do
  echo "=== $d ==="
  for f in device vendor status features; do
    [ -f "$d/$f" ] && echo "$f: $(cat $d/$f)"
  done
done
""", timeout=15)

    # ACPI Tables
    run_and_save("acpi_tables", "tables_listing.txt", "ls -la /sys/firmware/acpi/tables/", timeout=10, sudo=True)
    run_and_save("acpi_tables", "tables_hex_samples.txt", """
for t in /sys/firmware/acpi/tables/*; do
  if [ -f "$t" ]; then
    echo "=== $(basename $t) ==="
    xxd -p "$t" | head -n 30
  fi
done
""", timeout=20, sudo=True)

    # 2. Storage & Boot
    run_and_save("storage_and_boot", "mounts_and_mountinfo.txt", "cat /proc/mounts; echo '--- MOUNTINFO ---'; cat /proc/self/mountinfo", timeout=10)
    run_and_save("storage_and_boot", "df_hT.txt", "df -hT", timeout=10)
    run_and_save("storage_and_boot", "lsblk.txt", "lsblk -f -a", timeout=10)
    run_and_save("storage_and_boot", "vdb_tune2fs.txt", "tune2fs -l /dev/vdb", timeout=15, sudo=True)
    run_and_save("storage_and_boot", "overlay_init.sh", "cat /usr/sbin/overlay-init 2>/dev/null || file /usr/sbin/overlay-init", timeout=10)
    run_and_save("storage_and_boot", "vda_superblock.hex", "dd if=/dev/vda bs=1024 count=1 2>/dev/null | xxd", timeout=15, sudo=True)
    run_and_save("storage_and_boot", "rom_listing.txt", "ls -la /rom; echo '--- /rom/usr ---'; ls -la /rom/usr 2>/dev/null; echo '--- /rom/opt ---'; ls -la /rom/opt 2>/dev/null", timeout=15)

    # 3. Systemd, IPC & devbox-session
    run_and_save("systemd_and_ipc", "vmm_notify_socket.txt", "ls -laR /run/credentials/; echo '--- CONTENT ---'; cat /run/credentials/@system/vmm.notify_socket 2>/dev/null", timeout=10, sudo=True)
    run_and_save("systemd_and_ipc", "devbox-ssh-over-vsock.service", "cat /etc/systemd/system/devbox-ssh-over-vsock.service 2>/dev/null", timeout=10)
    run_and_save("systemd_and_ipc", "var-lib-systemd.mount", "cat /etc/systemd/system/var-lib-systemd.mount 2>/dev/null", timeout=10)
    run_and_save("systemd_and_ipc", "enabled_units.txt", "systemctl list-unit-files --state=enabled,generated --no-pager", timeout=15)
    run_and_save("systemd_and_ipc", "devbox_session_listing.txt", "ls -laR /run/devbox-session/", timeout=10, sudo=True)
    run_and_save("systemd_and_ipc", "devbox_session_files.txt", "head -n 100 /run/devbox-session/default/* 2>/dev/null", timeout=10, sudo=True)
    run_and_save("systemd_and_ipc", "ss_vsock.txt", "ss -a --vsock -p 2>/dev/null || ss -a --vsock", timeout=10, sudo=True)
    run_and_save("systemd_and_ipc", "supervisor_processes.txt", "ps aux | grep -E 'swebot|tmux|devbox|inotifywait|tailcat' | grep -v grep", timeout=10)

    # 4. Network, Routing & Gateway Probes
    run_and_save("network_and_proxy", "ip_addr_link.txt", "ip -d link show; echo '--- ADDR ---'; ip -4 addr show; ip -6 addr show", timeout=10)
    run_and_save("network_and_proxy", "routing_rules.txt", "ip route show table all; echo '--- RULES ---'; ip rule show", timeout=10)
    run_and_save("network_and_proxy", "ethtool_offloads.txt", "ethtool -k eth0 2>/dev/null || ethtool eth0 2>/dev/null || true", timeout=10)
    run_and_save("network_and_proxy", "iptables_nftables.txt", "iptables-save; echo '--- NFT ---'; nft list ruleset 2>/dev/null || true", timeout=15, sudo=True)
    run_and_save("network_and_proxy", "resolv_hosts.txt", "cat /etc/resolv.conf; echo '--- HOSTS ---'; cat /etc/hosts; echo '--- NSSWITCH ---'; cat /etc/nsswitch.conf", timeout=10)
    run_and_save("network_and_proxy", "git_configs.txt", "git config --system --list --show-origin 2>/dev/null; echo '--- GLOBAL ---'; git config --global --list --show-origin 2>/dev/null", timeout=10)
    run_and_save("network_and_proxy", "proxy_headers.txt", "curl -s -i http://192.168.0.1:8080/; echo '--- HEALTHZ ---'; curl -s -i http://192.168.0.1:8080/healthz", timeout=15)
    run_and_save("network_and_proxy", "host_gateway_ports.txt", """
for p in 22 53 80 443 8080 9999; do
  timeout 1 bash -c "echo > /dev/tcp/192.168.0.1/$p" 2>/dev/null && echo "Port $p: OPEN" || echo "Port $p: CLOSED"
done
""", timeout=15)
    run_and_save("network_and_proxy", "vsock_cid2_probe.txt", """python3 -c "
import socket
for port in [22, 53, 8080, 9999]:
    try:
        s = socket.socket(socket.AF_VSOCK, socket.SOCK_STREAM)
        s.settimeout(1)
        s.connect((2, port))
        print(f'VSOCK CID 2 Port {port}: OPEN')
        s.close()
    except Exception as e:
        print(f'VSOCK CID 2 Port {port}: CLOSED ({e})')
" """, timeout=15)

    # 5. Security & Auth
    run_and_save("security_and_auth", "sudoers.txt", "cat /etc/sudoers; echo '--- SUDOERS.D ---'; cat /etc/sudoers.d/*", timeout=10, sudo=True)
    run_and_save("security_and_auth", "passwd_group.txt", "cat /etc/passwd; echo '--- GROUP ---'; cat /etc/group", timeout=10)
    run_and_save("security_and_auth", "capabilities.txt", "cat /proc/1/status | grep -i cap; echo '--- CURRENT ---'; cat /proc/$$/status | grep -i cap", timeout=10, sudo=True)
    run_and_save("security_and_auth", "seccomp.txt", "cat /proc/1/status | grep -i seccomp; echo '--- CURRENT ---'; cat /proc/$$/status | grep -i seccomp", timeout=10)
    run_and_save("security_and_auth", "sshd_config.txt", "cat /etc/ssh/sshd_config; echo '--- SSHD_CONFIG.D ---'; cat /etc/ssh/sshd_config.d/* 2>/dev/null || true", timeout=10, sudo=True)
    run_and_save("security_and_auth", "host_keys.txt", "for f in /etc/ssh/ssh_host_*_key.pub; do [ -f \"$f\" ] && ssh-keygen -l -f \"$f\"; done", timeout=10)
    run_and_save("security_and_auth", "suid_sgid.txt", "find / -xdev \\( -perm -4000 -o -perm -2000 \\) -ls 2>/dev/null", timeout=20, sudo=True)

    print("\n[✔] Telemetry sweep complete!")

if __name__ == "__main__":
    main()
