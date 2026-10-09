# Kernel Sysctl and Binfmt_misc Configuration

## 1. Tuned Sysctl Kernel Parameters

Captured sysctl parameters (`sysctl -a 2>/dev/null | grep -E 'fs.epoll|fs.aio|fs.fanotify|abi.vsyscall'`):

```text
abi.vsyscall32 = 1
fs.aio-max-nr = 65536
fs.aio-nr = 0
fs.epoll.max_user_watches = 1813414
fs.fanotify.max_queued_events = 16384
fs.fanotify.max_user_groups = 128
fs.fanotify.max_user_marks = 68597
```

### Non-Standard Deviations from Stock Ubuntu 24.04 Defaults
- `fs.epoll.max_user_watches = 1813414` (significantly raised above standard stock default ~200,000 to handle large monorepo IDE file watching).
- `fs.aio-max-nr = 65536` (lowered/tuned async I/O request limit).
- `abi.vsyscall32 = 1` (enabled 32-bit vsyscall support for legacy binary compatibility).

## 2. Binfmt_misc Binary Execution Handlers

Listing `/proc/sys/fs/binfmt_misc/`:

```text
python3.12
register
status
```

Content of `/proc/sys/fs/binfmt_misc/python3.12`:

```text
enabled
interpreter /usr/bin/python3.12
flags:
offset 0
magic cb0d0d0a
```

The system registers a direct binary execution handler for Python 3.12 bytecode files (`.pyc`) using magic bytes `cb0d0d0a`.
