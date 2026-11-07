# Cross-Repo Probe Transfer: Spark, Muse → Jules

The sibling dissections were used as a probe checklist against this Jules devbox.
This records **which techniques transferred**, the **new results**, and where Jules
differs from the other runtimes.

Raw: [`raw/guest_host_comms_20261107T102856Z/system/`](raw/guest_host_comms_20261107T102856Z/system/)
(`unix_sockets.txt`, `virtio_serial_and_mounts.txt`, `crossrepo_tls_dns.txt`,
`crossrepo_vsock_logind.txt`, `syscall_matrix.txt`, `userns_depth.txt`,
`root_cap_probes.txt`, `lsm_active.txt`).

Sources:
- `sys-dissect/gemini-spark-sandbox-architecture` (gVisor: Unix-socket/FD matrix, syscall matrix, 9P/FUSE, userns)
- `sys-dissect/meta-muse-sandbox-architecture` (Cloud Hypervisor: VSOCK CID2:512, egress CA/TLS MITM, RFC2544 DNS VIP, supervisor)
- `sys-dissect/jiopc-architecture-whitepaper` (Azure VDI: logind linger/killswitch, proxy/PAC, TUN/CAP_NET_ADMIN)

---

## 1. Technique transfer matrix

| Borrowed from | Probe | Applied to Jules | Result |
| :--- | :--- | :--- | :--- |
| Spark | Full Unix-domain-socket matrix (`ss -xap`, `/proc/net/unix`) | ✅ | Only standard systemd/dbus/journal/containerd/docker/tmux/sshd/opencode sockets; **no hidden host bridge** |
| Spark | `/proc` FD map of daemons | ✅ | `socat`, `sshd`, `tailcat`, `opencode`, `containerd`, `dockerd` only |
| Spark | 9P/FUSE/host-share mounts | ✅ | No 9P/virtiofs/NFS/CIFS/FUSE mounts; root is overlay+SquashFS+ext4+tmpfs |
| Spark | Guest agent / virtio-serial / vport | ✅ | **None** — only `/dev/ttyS0`; `CONFIG_VIRTIO_CONSOLE=y` but no device instantiated |
| Spark | Multi-syscall ctypes matrix | ✅ | See §2 |
| Spark | `unshare` flag behaviour | ✅ | userns allowed; all other namespaces need root |
| Muse | VSOCK CID 2:512 hypervisor channel | ✅ | **closed** (full CID 2 sweep = 0/65535) |
| Muse | Egress CA / TLS interception | ✅ | **No MITM** — real Sectigo cert, no custom CA, no `*_CA_*` env |
| Muse | RFC2544 synthetic DNS VIP (198.18/15) | ✅ | **No** — real public IPs returned |
| Muse | Guest supervisor / `spawnd`-style agent | ✅ | **None** |
| JioPC | logind linger / session killswitch | ✅ | `Linger=no`, no `logind.conf` overrides, 5 live sessions, `IdleHint=no` |
| JioPC | Egress proxy / PAC | ✅ | No PAC/proxy env; direct HTTPS egress (unlike JioPC's mandatory `:3128`) |
| JioPC | `/dev/net/tun` + `CAP_NET_ADMIN` | ✅ | `/dev/net/tun` + `/dev/fuse` present, world-writable; root has full caps |

---

## 2. Kernel / syscall boundary (Jules-specific)

Capabilities: default `jules` shell = `CapEff 0x0` (bounding set full);
`sudo` = **full** caps (`0x1ffffffffff`).

| Probe | `jules` (uid 1001) | root |
| :--- | :--- | :--- |
| `memfd_create` | OK | OK |
| `memfd_secret` (`CONFIG_SECRETMEM=y`) | OK | OK |
| `io_uring_setup` (`CONFIG_IO_URING=y`) | OK | OK |
| `unshare(CLONE_NEWUSER)` | **OK** | OK |
| `unshare(CLONE_NEWNS/NEWPID/NEWNET/NEWUTS/NEWIPC/NEWCGROUP/NEWTIME)` | EPERM | OK |
| `unshare -Ur --map-root-user` → `id` | **uid=0(root)** | — |
| mount tmpfs in userns+mountns | **OK** | OK |
| create netns in userns (`unshare -Urn`) | **OK** | OK |
| `bpf(BPF_MAP_CREATE)` valid attr | EPERM (`unprivileged_bpf_disabled=2`) | **OK** |
| `perf_event_open` | EACCES (`perf_event_paranoid=2`) | **OK** |
| `open_by_handle_at` | EPERM | proceeds (`EFAULT` with NULL handle) |
| `pivot_root(NULL)` | EPERM | `EFAULT` (syscall reachable) |
| `fsopen`/`open_tree` | EPERM | OK |
| `userfaultfd` | **ENOSYS** (compiled out) | ENOSYS |
| `kexec_load` | **ENOSYS** (compiled out) | ENOSYS |
| `landlock_create_ruleset` | **ENOSYS** (compiled out) | ENOSYS |

Other sysctls: `kernel.dmesg_restrict=0`, `kernel.kptr_restrict=1`,
`kernel.io_uring_disabled=0`, `kernel.unprivileged_bpf_disabled=2`,
`kernel.perf_event_paranoid=2`.

### 2.1 Security subsystem is entirely absent

```text
# CONFIG_SECURITY is not set
# CONFIG_SECURITYFS is not set
# CONFIG_AUDIT is not set
# CONFIG_SECCOMP is not set
```

`/proc/self/attr/` and `/sys/kernel/security/` do not exist; there is no Yama,
AppArmor, SELinux, Smack, TOMOYO, Landlock, seccomp or audit. The
`CONFIG_LSM="lockdown,yama,…"` line in the config file is inert when
`CONFIG_SECURITY` is off. This is a stronger statement than "no LSM configured":
the whole security framework is compiled out.

### 2.2 User namespaces are the one unprivileged escalation surface

Despite `CapEff 0x0`, an unprivileged `jules` process can create a **user
namespace** and map itself to uid 0 inside it, then create **mount, network and
PID namespaces** and mount `tmpfs`. This is a notable kernel surface (e.g. for
unprivileged filesystem/network tooling), though it does not cross the
Firecracker/KVM boundary.

---

## 3. Comparison matrix

| Dimension | **Jules** (Firecracker KVM) | Spark (gVisor) | Muse (Cloud Hypervisor + nspawn) | JioPC (Azure VDI) |
| :--- | :--- | :--- | :--- | :--- |
| Isolation | KVM microVM, `pci=off` | gVisor user-space kernel | Cloud Hypervisor + `systemd-nspawn` | Azure VM + XRDP |
| Syscall filtering | **none** (`CONFIG_SECCOMP` off) | Sentry interception | seccomp BPF | none observed |
| LSM / audit | **none** (`CONFIG_SECURITY` off) | gVisor | Sentinel/eBPF | — |
| User namespaces | **enabled** (unprivileged) | gVisor | user ns (`0→131072`) | — |
| Host channel | TCP SSH host→guest; VSOCK idle | `runsc exec` + UDS | VSOCK **CID 2:512 open** | RDP/Accops |
| Guest→host init | DNS/HTTP/ICMP only | — | VSOCK/dial | proxy |
| TLS interception | **no** (real certs) | — | **yes** (egress CA) | proxy |
| DNS synthetic VIP | **no** (real IPs) | — | **yes** (198.18/15) | internal DNS |
| Egress | open HTTPS+UDP; metadata blocked | **air-gap** | proxied | **proxy-only** |
| Session killswitch | none (`Linger=no`, no overrides) | — | — | **15-min XRDP kill** |

Jules sits between Spark (air-gapped) and Muse/JioPC (mediated egress): it has
**open egress and no syscall/LSM filtering**, but the host boundary is a
Firecracker microVM with no guest→host control channel.

---

## 4. Ideas from the siblings not yet executed (optional)

- **Sentinel-style scrub test (Muse):** write a token-shaped canary to a repo file /
  session stdout and check whether the host's diff harvester or the agent scrub
  redacts it in the harvested transcript. Would reveal an output-screening layer.
- **FUSE-in-userns mount (Spark):** `CONFIG_FUSE_FS=y` and `/dev/fuse` are present;
  test whether an unprivileged userns can mount a FUSE filesystem.
- **File-handle escape (Spark/Muse themes):** root holds `CAP_DAC_READ_SEARCH`
  (`open_by_handle_at` reaches `EFAULT`); the default user is correctly denied.
- **`perf_event_open` as root** and **BPF maps as root** were confirmed working
  (capability boundary), useful for kernel tracing if needed.

## 5. Verdict

Yes — the sibling repos were useful. Spark's IPC/syscall/userns checklist found
**no hidden guest-agent channel** and mapped the userns surface; Muse's egress
checks proved Jules has **no TLS interception and no synthetic DNS VIP**, and its
VSOCK 512 channel is **closed**; JioPC's session checks show Jules has **no
killswitch/linger policy**. The only new *correction* is strengthening
"no LSM/seccomp" to "**entire security subsystem compiled out**".
