# Evidence Hardening

## Harness Evidence
`ls -la /run`:
total 20
drwxr-xr-x 17 root root    500 Oct  5 08:18 .
drwxr-xr-x  1 root root   4096 Oct  5 06:35 ..
-rw-------  1 root root      0 Oct  5 06:35 agetty.reload
drwx--x--x  6 root root    160 Mar  6  2026 containerd
drwxr-xr-x  3 root root     60 Oct  5 06:35 credentials
drwxr-xr-x  3 root root     80 Mar  6  2026 dbus
drwxr-xr-x  3 root root     60 Oct  5 06:35 devbox-session
drwx------  4 root root    100 Oct  5 06:35 docker
-rw-r--r--  1 root root      3 Oct  5 06:35 docker.pid
srw-rw----  1 root docker    0 Mar  6  2026 docker.sock
prw-------  1 root root      0 Mar  6  2026 initctl
drwxrwxrwt  3 root root     60 Mar  6  2026 lock
drwxr-xr-x  3 root root     60 Mar  6  2026 log
-rw-r--r--  1 root root    192 Oct  5 08:18 motd.dynamic
drwxr-xr-x  2 root root     40 Mar  6  2026 mount
drwxr-xr-x  2 root root     40 Mar  6  2026 sendsigs.omit.d
drwxr-xr-x  2 root root     40 Mar  6  2026 setrans
lrwxrwxrwx  1 root root      8 Mar  6  2026 shm -> /dev/shm
drwxr-xr-x  2 root root     40 Mar  6  2026 sshd
-rw-r--r--  1 root root      4 Mar  6  2026 sshd.pid
drwx--x--x  2 root root     40 Mar  6  2026 sudo
drwxr-xr-x 20 root root    520 Oct  5 08:54 systemd
drwxr-xr-x  6 root root    140 Oct  5 08:18 udev
drwxr-xr-x  3 root root     60 Mar  6  2026 user
-rw-rw-r--  1 root utmp   2304 Oct  5 08:01 utmp

`ls -la /run/devbox-session/default/`:
total 4
drwxrwxrwx 2 jules root  120 Oct  5 08:54 .
drwxr-xr-x 3 root  root   60 Oct  5 06:35 ..
-rw-r--r-- 1 jules jules 469 Oct  5 08:54 command
-rw-rw-r-- 1 jules jules   0 Oct  5 08:54 stderr
-rw-r--r-- 1 jules jules   0 Oct  5 08:54 stdin
-rw-rw-r-- 1 jules jules   0 Oct  5 08:54 stdout

`find /run -maxdepth 2`:
/run
/run/lock
/run/lock/subsys
/run/systemd
/run/systemd/system
/run/systemd/mount-rootfs
/run/systemd/inaccessible
/run/systemd/propagate
/run/systemd/units
/run/systemd/show-status
/run/systemd/generator
/run/systemd/notify
/run/systemd/private
/run/systemd/userdb
/run/systemd/io.systemd.ManagedOOM
/run/systemd/systemd-units-load
/run/systemd/ask-password
/run/systemd/journal
/run/systemd/io.systemd.sysext
/run/systemd/incoming
/run/systemd/netif
/run/systemd/seats
/run/systemd/sessions
/run/systemd/users
/run/systemd/machines
/run/systemd/shutdown
/run/systemd/inhibit
/run/systemd/transient
/run/credentials
/run/credentials/@system
/run/initctl
/run/udev
/run/udev/control
/run/udev/links
/run/udev/tags
/run/udev/data
/run/udev/watch
/run/mount
/run/log
/run/log/journal
/run/dbus
/run/dbus/containers
/run/dbus/system_bus_socket
/run/shm
/run/sendsigs.omit.d
/run/setrans
/run/sudo
/run/user
/run/user/1001
/run/utmp
/run/docker.sock
/run/sshd
/run/sshd.pid
/run/containerd
/run/agetty.reload
/run/docker
/run/docker.pid
/run/devbox-session
/run/devbox-session/default
/run/motd.dynamic

## Namespace Evidence
`cat /proc/self/uid_map`:
         0          0 4294967295

`cat /proc/self/gid_map`:
         0          0 4294967295

`readlink /proc/self/ns/*`:
cgroup:[4026531835]
ipc:[4026531839]
mnt:[4026531841]
net:[4026531840]
pid:[4026531836]
pid:[4026531836]
time:[4026531834]
time:[4026531834]
user:[4026531837]
uts:[4026531838]

`systemd-detect-virt`:
kvm

## Services Evidence
`systemctl list-units --type=service --state=running`:
  UNIT                          LOAD   ACTIVE SUB     DESCRIPTION
  containerd.service            loaded active running containerd container runtime
  dbus.service                  loaded active running D-Bus System Message Bus
  devbox-ssh-over-vsock.service loaded active running devbox-ssh-over-vsock.service
  docker.service                loaded active running Docker Application Container Engine
  getty@tty1.service            loaded active running Getty on tty1
  serial-getty@ttyS0.service    loaded active running Serial Getty on ttyS0
  ssh.service                   loaded active running OpenBSD Secure Shell server
  systemd-journald.service      loaded active running Journal Service
  systemd-logind.service        loaded active running User Login Management
  systemd-udevd.service         loaded active running Rule-based Manager for Device Events and Files
  user@1001.service             loaded active running User Manager for UID 1001

Legend: LOAD   → Reflects whether the unit definition was properly loaded.
        ACTIVE → The high-level unit activation state, i.e. generalization of SUB.
        SUB    → The low-level unit activation state, values depend on unit type.

11 loaded units listed.

`docker ps`:
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES

`docker images`:
WARNING: This output is designed for human readability. For machine-readable output, please use --format.
IMAGE   ID             DISK USAGE   CONTENT SIZE   EXTRA

## Egress Evidence
`curl -sS -o /dev/null -w '%{http_code}' -m 10 https://registry.npmjs.org/`:
200
`curl -sS -o /dev/null -w '%{http_code}' -m 10 https://pypi.org/`:
200
`curl -sS -o /dev/null -w '%{http_code}' -m 10 https://proxy.golang.org/`:
200
`curl -sS -o /dev/null -w '%{http_code}' -m 10 https://google.com/`:
301
`curl -sS -o /dev/null -w '%{http_code}' -m 10 https://github.com/`:
200

## Image Census Evidence
`ls -la /opt`:
total 16
drwxr-xr-x  1 root  root  4096 Mar  6  2026 .
drwxr-xr-x  1 root  root  4096 Oct  5 06:35 ..
drwxr-xr-x  9 jules jules  145 Mar  2  2026 android-sdk
drwx--x--x  4 root  root  4096 Mar  6  2026 containerd
-r-xr-xr-x  1 root  root  3298 Mar  6  2026 environment_summary.sh
drwxr-xr-x 33 jules jules  585 Mar  2  2026 flutter
drwxr-xr-x  3 root  root    29 Mar  2  2026 google
drwxr-xr-x  4 root  root    45 Mar  2  2026 jules

`ls -la /usr/local/bin`:
total 3214
drwxr-xr-x  5 root root      60 Mar  2  2026 .
drwxr-xr-x 13 root root     144 Mar  2  2026 ..
-rwxr-xr-x  1 root root     563 Mar  2  2026 bundle
-rwxr-xr-x  1 root root     565 Mar  2  2026 bundler
-rwxr-xr-x  1 root root 3288946 Feb 13  2026 composer

`ls -la /usr/local/lib`:
total 0
drwxr-xr-x  3 root root  33 Mar  2  2026 .
drwxr-xr-x 13 root root 144 Mar  2  2026 ..
drwxr-xr-x  3 root root  36 Mar  2  2026 python3.12
