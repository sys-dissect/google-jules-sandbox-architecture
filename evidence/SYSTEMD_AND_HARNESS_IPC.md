# Systemd & Harness Inter-Process Communication (IPC)

Comprehensive audit of guest systemd services, AF_VSOCK socket bridges, tmpfs performance optimizations, and orchestration synchronization.

---

## 1. Devbox Session Watcher & VSOCK Relay Commands

The Jules host orchestration engine interacts with the guest environment via a dedicated command harness:

```text
root         876 /usr/bin/socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
jules       2344 tmux new-session -d -s default -c /app -e JULES_SESSION_ID=1732599560545719224 -e GIT_TERMINAL_PROMPT=0
jules      74594 bash -c echo "${BASHPID}" RUN_ROOT_DIR=/run/devbox-session/default PANE_PID="2345" ... inotifywait -e create,moved_to --include '/stamp$' "/run/devbox-session/default"
jules      74600 inotifywait -e create,moved_to --include /stamp$ /run/devbox-session/default
```

### Protocol Mechanics
1. **Host Ingress**: The host orchestrator connects to Guest CID 123 over AF_VSOCK port 22 via Firecracker's Unix domain socket on the host (`socat - UNIX-CONNECT:/tmp/firecracker-vsock.sock`).
2. **VSOCK Forwarder (`socat`)**: Runs as a systemd unit (`devbox-ssh-over-vsock.service`) forwarding `VSOCK-LISTEN:22` to `127.0.0.1:22` (`sshd`).
3. **Session Multiplexing (`tmux`)**: Holds state in persistent session `default` at `/app` across turns without re-allocating interactive TTYs.
4. **Execution Synchronization via File-Pipes**:
   - Turn instructions are staged into `/run/devbox-session/default/command`.
   - The tmux shell executes:
     ```bash
     PROMPT_COMMAND='__CODExx__=$?; echo $__CODExx__ > /run/devbox-session/default/exit_code && touch /run/devbox-session/default/stamp; unset PROMPT_COMMAND;'
     source /run/devbox-session/default/command < /run/devbox-session/default/stdin > /run/devbox-session/default/stdout 2> /run/devbox-session/default/stderr
     ```
   - On the host SSH worker thread, an asynchronous watcher blocks on the directory:
     ```bash
     coproc inw { inotifywait -e create,moved_to --include '/stamp$' /run/devbox-session/default; }
     tail --pid <PANE_PID> -f /dev/null
     ```
   - The moment `touch stamp` occurs, `inotifywait` unblocks immediately, and the host collects `exit_code`, `stdout`, and `stderr` with zero polling delays.

---

## 2. Direct AF_VSOCK Communication Mechanics

VSOCK (`AF_VSOCK = 40`) addresses endpoints using a 32-bit Context ID (CID) and a 32-bit port, completely bypassing IP networks, ARP, and routing tables.

### 1. Ingress: Host-to-Guest SSH
Firecracker bridges guest VSOCK to a host Unix domain socket:
```bash
# On the host:
socat - UNIX-CONNECT:/tmp/firecracker-vsock.sock
```
Inside the guest, `devbox-ssh-over-vsock.service` forwards port 22 to `127.0.0.1:22`, connecting the host orchestrator as user `swebot`.

### 2. Egress: Guest-to-Host VMM Lifecycle Heartbeat
A guest Python script can speak directly to the hypervisor (Host CID 2, port 9999):
```python
import socket

AF_VSOCK = 40
HOST_CID = 2     # Host hypervisor
VMM_PORT = 9999  # vmm.notify_socket

sock = socket.socket(AF_VSOCK, socket.SOCK_STREAM)
try:
    sock.connect((HOST_CID, VMM_PORT))
    sock.sendall(b"READY=1\nSTATUS=Initialization complete\n")
finally:
    sock.close()
```

---

## 2. VSOCK Forwarder Service Definition (`devbox-ssh-over-vsock.service`)

The systemd unit configuration for VSOCK SSH ingress:

```ini
[Unit]
After=sshd.service

[Service]
Type=simple
ExecStart=/usr/bin/socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target
```

### Architectural Notes from Unit Comments:
> *"For systemd > 256 there is also a systemd-ssh-generator(8) that can configure sshd over vsock. We use a somewhat old ubuntu for guest that has systemd 255. So the approach here is slightly more portable. Revisit this in a few years. c.f. https://libvirt.org/ssh-proxy.html#guest-os-requirements"*

---

## 3. Systemd tmpfs Optimization (`var-lib-systemd.mount`)

In standard Linux systems, `/var/lib/systemd` resides on the root filesystem. In Google Jules:

```text
tmpfs on /var/lib/systemd type tmpfs (rw,nosuid,nodev,size=4075060k,nr_inodes=10240)
```

### Systems Rationale:
* **OverlayFS Write Reduction**: Systemd actively records service state, catalog data, and transient runtime metadata in `/var/lib/systemd`.
* **Zero Persistence Overhead**: By binding a 4 GiB dedicated `tmpfs` to `/var/lib/systemd`, all systemd runtime churn is retained in volatile memory rather than committing unnecessary copy-up writes to the ext4 upperdir (`/dev/vdb`), maximizing disk I/O throughput and preventing scratch disk bloat.

---

## 4. Systemd Credentials & VMM Notification Socket

Inspection of `/proc/cmdline` and `/run/credentials/`:
```text
systemd.set_credential=vmm.notify_socket:vsock-stream:2:9999
```
The kernel transfers the notification socket location directly to systemd via credential injection. When systemd completes initialization, or on lifecycle events, it communicates directly with Firecracker (Host CID 2, port 9999) via `vmm.notify_socket`.

---

## 5. Harness Process Hierarchy

```text
systemd (PID 1)
 ├─ systemd-journald (PID 439)
 ├─ systemd-udevd (PID 790)
 ├─ systemd-logind (PID 841)
 ├─ dbus-daemon (PID 833)
 ├─ containerd (PID 872)
 ├─ dockerd (PID 911)
 ├─ socat (PID 876) [VSOCK-LISTEN:22 -> TCP4:127.0.0.1:22]
 ├─ sshd (PID 874)
 │   └─ sshd: swebot (PID 877) -> tmux (PID 2344) -> bash (PID 2345)
 └─ systemd --user (PID 887)
```
