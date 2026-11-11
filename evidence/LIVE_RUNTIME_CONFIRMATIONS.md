# Live Runtime Confirmations (Egress, Containers, Tailcat)

Final live checks from **2026-11-07** before the VM expiry window. Raw:
[`raw/guest_host_comms_20261107T102856Z/system/`](raw/guest_host_comms_20261107T102856Z/system/).

---

## 1. Network topology & egress `[Tier 1]`

```text
$ sudo nmap -sn 192.168.0.0/24
Nmap scan report for 192.168.0.1   (host tap, MAC 42:D0:D9:5B:D3:31)
Nmap scan report for 192.168.0.2   (this guest)
```

Only the gateway and the guest exist on the /24. Default route is via
`192.168.0.1`; there is no other peer.

| Egress test | Result |
| :--- | :--- |
| `curl https://www.google.com` | `HTTP/2 200` (open outbound HTTPS) |
| `dig @8.8.8.8 github.com` | `140.82.114.4` (open outbound UDP/53) |
| `ip route get 8.8.8.8` | via `192.168.0.1 dev eth0 src 192.168.0.2` |
| Cloud metadata (GCP/AWS, IPv6) | unreachable (connect refused) — see [`VMGENID_AND_SNAPSHOT_FORK.md`](VMGENID_AND_SNAPSHOT_FORK.md) |

`traceroute`/`tracepath` are not installed, so the downstream hop path could not be
enumerated. This confirms the repo's "open outbound HTTPS & UDP" claim while noting
the metadata endpoint is specifically blackholed.

---

## 2. Container runtime `[Tier 1]`

```text
$ sudo docker info (selected)
Server Version: 29.2.1
Storage Driver: overlayfs
 driver-type: io.containerd.snapshotter.v1
Cgroup Driver: systemd / Cgroup Version: 2
Containers: 0   Images: 1
Docker Root Dir: /var/lib/docker
```

```text
$ sudo ctr namespaces list
moby
$ sudo ctr -n moby images list
docker.io/library/alpine:latest  ...  3.7 MiB  (multi-arch index)
```

`/etc/docker/daemon.json` is absent; `/etc/containerd/config.toml` is the stock
Docker file (`disabled_plugins = ["cri"]`). Storage footprint: `/var/lib/docker`
184 KiB, `/var/lib/containerd` 13 MiB, overlay upperdir `/rom/overlay` 2.0 GiB.

The single Alpine image is the artifact of this audit's `docker run` test, which
reproduced the overlay-on-overlay `EINVAL` documented in
[`CONTAINERD_DOCKER_RUNTIME.md`](CONTAINERD_DOCKER_RUNTIME.md). No containers are
running; Docker CE 29.2.1 uses the containerd `overlayfs` snapshotter by default.

---

## 3. Tailcat ingress binary & wiring `[Tier 1]`

```text
$ go version -m ~/go/bin/tailcat
... go1.27.3
    path  github.com/tailscale/tailcat/cmd/tailcat
    mod   github.com/tailscale/tailcat  v0.7.0
    dep   github.com/tailscale/wireguard-go ...
    dep   github.com/tailscale/gliderssh ...
    dep   github.com/pkg/sftp ...
```

- Tailcat is **v0.7.0** from the `tailscale/tailcat` project (user-space WireGuard +
  SSH/SFTP/exit-node server), not a Google-first-party component.
- The live invocation is `tailcat serve --ssh-authorized-keys=… ssh` — SSH only
  (no `files`/SFTP or `exit-node` service enabled).
- **Its stdio is bound to the Jules harness FIFO**:

  ```text
  /proc/10554/fd/0 -> /run/devbox-session/default/stdin
  /proc/10554/fd/1 -> /run/devbox-session/default/stdout
  /proc/10554/fd/2 -> /run/devbox-session/default/stderr
  ```

  i.e. the ingress server is itself launched as a long-running Jules command, so its
  output is harvested by the host's file-FIFO pipeline rather than appearing in the
  tmux scrollback.
- No local TCP/Unix control API is exposed (`ss -lxap`/`ss -ltnp` show no tailcat
  socket); the only network state is the outbound WireGuard flow to the DERP relay.
- The process holds many `/dev/ptmx` descriptors plus `pidfd`s — one PTY per inbound
  SSH session.
- DERP map is cached under `~/.cache/tailcat`; live relay is region `301` (NYC,
  `199.38.181.166`), consistent with [`TAILCAT_SSH.md`](TAILCAT_SSH.md).
- The per-session SSH host key is generated at startup
  (`~/.config/tailcat/ssh/ssh_host_ed25519_key`, created 09:07:15), while the peer
  identity comes from `TAILCAT_PEER_KEY`.

---

## 4. Summary of corrections this capture adds

1. Boot is **not sub-second**: `systemd-analyze` = 3.049 s kernel + 18.167 s
   userspace = 21.217 s to `graphical.target` (see
   [`AUTH_AND_BOOT_SURFACE.md`](AUTH_AND_BOOT_SURFACE.md)).
2. Control-plane transport is **TCP over virtio-net**, not VSOCK
   ([`GUEST_HOST_COMMS.md`](GUEST_HOST_COMMS.md)).
3. Host gateway exposes only **dnsmasq :53 + Python :8080**; the :8080 service is a
   GET/POST reverse proxy, not a forward proxy
   ([`GOLDEN_IMAGE_AND_HOST_SURFACE.md`](GOLDEN_IMAGE_AND_HOST_SURFACE.md)).
4. Snapshot resumes are detected via **VMGenID** (`FCVMGID`/`VM_Gen_Counter`)
   ([`VMGENID_AND_SNAPSHOT_FORK.md`](VMGENID_AND_SNAPSHOT_FORK.md)).
