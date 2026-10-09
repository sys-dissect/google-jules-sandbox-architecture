# Systemd & Harness Inter-Process Communication (IPC)

## 1. Devbox Session Watcher & VSOCK Relay Commands

Captured process execution commands (`ps aux | grep -E 'inotifywait|socat|tmux'`):

```text
root         876 /usr/bin/socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
jules       2344 tmux new-session -d -s default -c /app -e JULES_SESSION_ID=1732599560545719224 -e GIT_TERMINAL_PROMPT=0
jules      74594 bash -c echo "${BASHPID}" RUN_ROOT_DIR=/run/devbox-session/default PANE_PID="2345" ... inotifywait -e create,moved_to --include '/stamp$' "/run/devbox-session/default"
jules      74600 inotifywait -e create,moved_to --include /stamp$ /run/devbox-session/default
```

## 2. VSOCK-Listen to Localhost Socket Bridge Mapping

`ss -tlnp` socket binding:

```text
LISTEN 0 0 0.0.0.0:22 0.0.0.0:* (sshd)
LISTEN 0 0 *:22 *:* (sshd)
```

The Firecracker hypervisor host communicates with the guest over AF_VSOCK CID port 22. The `socat` daemon listens on `VSOCK-LISTEN:22` and forwards TCP traffic to `127.0.0.1:22` (`sshd`).

## 3. Harness Process Tree (PID 1 Down)

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
