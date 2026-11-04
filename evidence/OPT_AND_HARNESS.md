# Tooling, Runtime Environment & Automation Harness

Direct empirical census of development toolchains, browser automation engines, process trees, and VSOCK orchestration services.

---

## 1. Environment Diagnostic Script (`/opt/environment_summary.sh`)

Google pre-bakes a comprehensive diagnostics script into the golden rootfs image:

```bash
#!/usr/bin/env bash
#
# A diagnostic script to check the versions of installed development tools
# without altering the current shell environment. It reports what is
# currently active and will print "not found" if a tool isn't
# available in the current PATH.
#

# --- Helper Functions ---

# Prints a styled header.
print_header() {
  echo ""
  echo "--------- $1 ---------"
}

# Checks for a command and prints its version if found.
# Arguments:
#   $1: The command name to check (e.g., "python3").
#   $2: The arguments to get the version (e.g., "--version").
#   $3: The optional string to grep for in the version output.
check_command() {
  COMMAND="$1"
  VERSION_FLAG="$2"
  GREP="${3-""}"
  if command -v "$COMMAND" &> /dev/null; then
    echo -n "✅  $1: "
    if [ -z "$GREP" ]; then
      "$COMMAND" $VERSION_FLAG | head -n 10
    else
      "$COMMAND" $VERSION_FLAG | grep "$GREP" | head -n 10
    fi

  else
    echo "❌  $1: not found"
  fi
}

# --- Environment Checks ---

echo "-------------------------------------"
echo "Environment check starting..."

print_header "Python"
check_command python3 --version
check_command python --version
check_command pip --version
check_command pipx --version
check_command poetry --version
check_command uv --version
check_command black --version
check_command mypy --version
check_command pytest --version
check_command ruff --version
if command -v pyenv &> /dev/null; then
  echo "✅  pyenv: available"
  pyenv versions
else
  echo "❌  pyenv: not found"
fi

print_header "NodeJS"
check_command node --version
if [ -s "$NVM_DIR/nvm.sh" ] && nvm ls --no-alias; then
  echo "✅  nvm: available"
else
  echo "❌  nvm: not found"
fi
check_command npm --version
check_command yarn --version
check_command pnpm --version
check_command eslint --version
check_command prettier --version
check_command chromedriver --version

print_header "Java"
check_command java -version 2>&1
check_command mvn --version
check_command gradle --version Gradle

print_header "Go"
check_command go version

print_header "Rust"
check_command rustc --version
check_command cargo --version

print_header "Bun"
check_command bun --version

print_header "C/C++ Compilers"
check_command clang --version
check_command gcc --version
check_command cmake --version
check_command ninja --version
check_command conan --version

print_header "Android"
check_command sdkmanager --list_installed

print_header "Flutter"
check_command flutter --version

print_header "PHP"
check_command php -v
check_command composer --version

print_header "Ruby"
check_command ruby --version
check_command gem -v
check_command bundle -v

print_header ".NET"
check_command dotnet --list-sdks

print_header "Docker"
check_command docker --version
check_command docker "compose version"

print_header "PlayWright"
check_command playwright --version

print_header "Other Utilities"
check_command awk -V
check_command curl --version
check_command git --version
check_command grep --version
check_command gzip --version
check_command jq --version
check_command make --version
check_command rg --version
check_command sed --version
check_command tar --version
check_command tmux -V
check_command yq --version

echo ""
echo "-------------------------------------"
echo "Environment check complete."
```

---

## 2. Headless Browser Ecosystem & Image Directory Census

Google Jules equips the agent with a complete Google Chrome browser distribution and a Playwright test runner in `/opt/jules/` and `/opt/google/`:

```bash
$ find /opt/jules /opt/google -maxdepth 3 -ls
```

### Component Breakdown

| Directory / Binary | Size / Count | Technical Role |
| :--- | :--- | :--- |
| **`/opt/google/chrome/chrome`** | **268 MB** (268,012,760 bytes) | Full production Google Chrome 145 binary for headless DOM rendering and automated browsing |
| **`/opt/google/chrome/locales/`** | **58 locale `.pak` files** (~60 MB total) | Multi-language localization data (e.g. `en-US.pak`, `es.pak`, `ja.pak`, `de.pak`, `zh-CN.pak`, etc.) |
| **Widevine CDM (`WidevineCdm/`)** | Manifest & shared libs | Widevine Content Decryption Module support |
| **Vulkan SwiftShader (`libvk_swiftshader.so`)** | 4.3 MB | CPU-based software Vulkan ICD renderer for GPU-free 3D/canvas acceleration in microVMs |
| **Playwright Virtualenv (`/opt/jules/pipx`)** | Dedicated pipx venv | Isolated Python virtual environment providing `/opt/jules/playwright/bin/playwright` |

---

## 3. Process Tree & Harness Hierarchy

The guest system process hierarchy captured via `pstree -apnh`:

```text
systemd,1
  |-systemd-journal,439
  |-systemd-udevd,790
  |-dbus-daemon,833 --system --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
  |-systemd-logind,841
  |-agetty,844 -o -p -- \\u --noclear - linux
  |-agetty,845 -o -p -- \\u --keep-baud 115200,57600,38400,9600 - vt220
  |-containerd,872
  |   |-{containerd},879
  |   |-{containerd},880
  |   |-{containerd},881
  |   |-{containerd},882
  |   |-{containerd},883
  |   |-{containerd},884
  |   |-{containerd},909
  |   `-{containerd},912
  |-sshd,874
  |   |-sshd,877
  |   |   `-sshd,907
  |   `-sshd,918
  |       `-sshd,929
  |           `-bash,6351 -c...
  |               |-inotifywait,6356 -e create,moved_to --include /stamp$ /run/devbox-session/default
  |               `-bash,6357 -c...
  |                   `-tail,6361 --pid 2349 -f /dev/null
  |-socat,876 -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
  |-systemd,887 --user
  |   `-(sd-pam),888
  |-dockerd,911 -H fd:// --containerd=/run/containerd/containerd.sock
  |   |-{dockerd},944
  |   |-{dockerd},945
  |   |-{dockerd},946
  |   |-{dockerd},947
  |   |-{dockerd},954
  |   |-{dockerd},1251
  |   |-{dockerd},1265
  |   |-{dockerd},1277
  |   `-{dockerd},1443
  `-tmux: server,2348 new-session -d -s default -c /app -e JULES_SESSION_ID=13437284186659263797 -e GIT_TERMINAL_PROMPT=0
      `-bash,2349
          `-bash,6373 run_checks.sh
              `-pstree,6376 -apnh
```

---

## 4. VSOCK Forwarder Service Definition

The host hypervisor connects to guest SSH over AF_VSOCK via `devbox-ssh-over-vsock.service`:

```ini
# /etc/systemd/system/devbox-ssh-over-vsock.service
# Forwards VSOCK:22 to localhost:22
#
# For systemd > 256 there is also a systemd-ssh-generator(8) that can configure
# sshd over vsock. We use a somewhat old ubuntu for guest that has systemd 255.
# So the approach here is slightly more portable. Revisit this in a few years.
#
# c.f. https://libvirt.org/ssh-proxy.html#guest-os-requirements
[Unit]
After=sshd.service

[Service]
Type=simple
ExecStart=/usr/bin/socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target
```

---

## 5. User Profile Structure

User `jules` (UID 1001, GID 1001) home directory layout:

```text
/home/jules:
drwxr-xr-x .android
drwxr-xr-x .cargo
drwxr-xr-x .conan2
drwxr-xr-x .config (flutter, go)
drwxr-xr-x .gradle
drwxr-xr-x .npm
drwxr-xr-x .nvm
drwxr-xr-x .pyenv
drwxr-xr-x .rustup
drwx------ .ssh
-rw-r--r-- .sudo_as_admin_successful
```
Pre-configured dotfiles allow instant SDK execution without interactive prompts or path initialization issues.
