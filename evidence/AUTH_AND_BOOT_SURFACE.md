# Auth Surface, Boot Timing & Agent Plane

Live measurements from **2026-11-07** (guest CID 123). Raw:
[`raw/guest_host_comms_20261107T102856Z/system/`](raw/guest_host_comms_20261107T102856Z/system/).

---

## 1. Boot timing — correcting the "sub-second" claim `[Tier 1]`

```text
$ systemd-analyze
Startup finished in 3.049s (kernel) + 18.167s (userspace) = 21.217s
graphical.target reached after 18.127s in userspace.
```

```text
$ systemd-analyze blame | head
7.530s docker.service
5.922s ldconfig.service
2.838s containerd.service
1.544s dpkg-db-backup.service
 908ms dev-vda.device
 900ms dev-vdb.device
 708ms user@1001.service
 579s ssh.service
 ...
```

Milestones:

| Milestone | Time |
| :--- | :--- |
| Kernel banner | `dmesg [0.000000]` |
| `systemd[1]` starts | `dmesg [3.607967]` |
| `sshd` listening on `0.0.0.0:22` / `[::]:22` | journal `17:10:36` (≈7 s after kernel start) |
| `devbox-ssh-over-vsock.service` started | journal `17:10:36` |
| `containerd` started | journal `17:10:39` |
| `docker.service` (slowest unit) | `+7.530s` |
| `graphical.target` | `18.127s` userspace |

So the earlier statement that Jules boots in **"sub-second"** time is not
supported: this capture shows **~3 s kernel + ~18 s userspace (21.2 s)** to
`graphical.target`, with `sshd` reachable ~7 s after kernel start. The kernel's
static networking (`ip=…:off`) is indeed configured at kernel init, but userspace
readiness is seconds, not sub-second. (`Startup finished in 613ms` is the
`systemd --user` manager for `user@1001`, not the system boot.)

> Caveat: this VM is a warm snapshot resume, so these timings describe a resumed
> userspace startup rather than a cold Firecracker power-on; even so, they are an
> order of magnitude above "sub-second".

---

## 2. Authentication surface `[Tier 1]`

```text
$ sudo sshd -T | grep -Ei 'port|permitroot|passwordauth|pubkey|authorizedkeys|forward|tunnel|maxsession|clientalive'
port 22
listenaddress 0.0.0.0:22
listenaddress [::]:22
permitrootlogin without-password
passwordauthentication yes
pubkeyauthentication yes
authorizedkeysfile .ssh/authorized_keys .ssh/authorized_keys2
allowtcpforwarding yes
gatewayports no
permittunnel no
maxsessions 10
clientaliveinterval 0
clientalivecountmax 3
```

- Inbound SSH is **socket-activated** (`ssh.socket`, `0.0.0.0:22` and `[::]:22`;
  systemd holds the listening sockets, `ssh.service` is `Type=notify`).
- **Password authentication is enabled**, and the baked `jules` account has a
  non-locked yescrypt hash (see §3 of
  [`GOLDEN_IMAGE_AND_HOST_SURFACE.md`](GOLDEN_IMAGE_AND_HOST_SURFACE.md)). With
  `jules ALL=(ALL) NOPASSWD: ALL`, a password login becomes root.
- `PermitRootLogin without-password` is moot in practice because `root` is locked
  and `jules`/`swebot` share UID `1001` with passwordless sudo.
- The same RSA public key is authorized for `root`, `jules` and `swebot`
  (`/etc/ssh/...`, `/root/.ssh/authorized_keys`, `/home/{jules,swebot}/.ssh/...`).
- The host-side `swebot` SSH sessions carry an **empty environment**; orchestration
  is command/file-driven, not env-driven.

---

## 3. Agent plane (OpenCode) `[Tier 1]`

The interactive agent is OpenCode `1.19.5`, configured at
`~/.config/opencode/opencode.json`:

```json
{
  "provider": {
    "goedelmachines": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Gödel Machines",
      "options": {
        "baseURL": "https://api.goedelmachines.com/v1",
        "apiKey": "<redacted>"
      },
      "models": { "deepseek-v4.1-flash": { "name": "DeepSeek V4.1 Flash" } }
    }
  }
}
```

- Model id: `deepseek-v4.1-flash`; provider `goedelmachines`; runtime `ai-sdk`.
- The API key is supplied via `GOEDEL_API_KEY` in `~/.bashrc` / `~/.profile`
  (added by the interactive setup, **not** baked into the image) and is omitted here.
- OpenCode logs show **allow-all permissions** for tools:
  `permission=* action.action=allow action.pattern=*` for `bash` and `webfetch`.
- The agent process also holds `TAILCAT_PEER_KEY` in its environment.

---

## 4. Host orchestration command mix `[Tier 1]`

From the live journal (excluding this extraction's own commands), the host issues a
continuous workspace-sync loop over the `swebot` SSH channel:

| Pattern | Count |
| :--- | :--- |
| `cd /app; git add -A` | 296 |
| `cd /app; git diff --minimal --binary -U3 984c37d…` | 137 |
| `cd /app; git show 984c37d…:README.md` | 75 |
| `git diff 984c37d… --diff-filter=AM --name-only` | 27 |
| harness stdin/command staging (`cat > /run/devbox-session/default/…`) | 54 each |
| prompt/stamp injection (`PROMPT_COMMAND`, tmux paste) | 54 |
| `mkdir -m777 -p /run/devbox-session/default` | 54 |
| loop over `README.md evidence/GUEST_HOST_COMMS.md` | 10 |
| bootstrap resolver/proxy probe | 5 |

The `git show base:README.md` and the loop over `README.md` + `GUEST_HOST_COMMS.md`
show the host is actively reading/processing the newly added evidence, and the
`git add -A` / binary `git diff` loop is how guest changes are harvested for the
host-side push.
