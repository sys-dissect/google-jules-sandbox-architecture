# Orchestration & Task Execution Lifecycle

Empirical analysis derived from audit logs, shell history, and journal telemetry (`evidence/raw_telemetry/journal_orchestration_filtered.txt`).

---

## 1. Complete Orchestration Lifecycle Sequence

The host hypervisor and Google Jules orchestration harness follow a deterministic 9-step execution lifecycle for every task invocation:

```
+─────────────────────────────────────────────────────────────────────────────────────────+
|                               HOST ORCHESTRATOR                                         |
+─────────────────────────────────────────────────────────────────────────────────────────+
   │
   │ 1. Resume & Resync
   ▼
[a. MicroVM Warm Resume & Clock Resync] (date -s @...)
   │
   │ 2. Network Routing
   ▼
[b. Network Resolver Setup] (nameserver 192.168.0.1, devbox-gateway.internal:53 probe)
   │
   │ 3. Interception Setup
   ▼
[c. Host Git Credential Interception] (url.http://git@192.168.0.1:8080/.insteadOf)
   │
   │ 4. Repo Initialization
   ▼
[d. Repository Clone] (/app on branch jules-<task_id>-<hash>)
   │
   │ 5. Session Harness
   ▼
[e. Headless Persistent Tmux Session] (session 'default', JULES_SESSION_ID, GIT_TERMINAL_PROMPT=0)
   │
   │ 6. Instruction Dispatch
   ▼
[f. Non-Interactive FIFO Command Routing] (/run/devbox-session/default/{command,stdin,stdout,stderr})
   │
   │ 7. Synchronization
   ▼
[g. Completion Signaling] (PROMPT_COMMAND: $? -> exit_code, touch stamp -> inotifywait)
   │
   │ 8. Telemetry Harvesting
   ▼
[h. Post-Command Diff Harvesting] (git diff --diff-filter=AM --name-only, git ls-files --others)
   │
   │ 9. Turn Boundary
   ▼
[i. Turn Finish & Hypervisor vCPU Pause] (random: crng reseeded due to virtual machine fork)
```

### Sequence Breakdown

### a. MicroVM Warm Resume and Clock Resync
Prior to executing commands, the orchestrator issues a time resynchronization call to update the VM wall clock after waking or cloning:
```text
Mar 06 17:10:39 devbox sudo[914]: jules : PWD=/home/jules ; USER=root ; COMMAND=/usr/bin/date -s @1772817039.7944698
...
Mar 06 17:10:40 devbox sudo[935]: jules : PWD=/home/jules ; USER=root ; COMMAND=/usr/bin/date -s @1791532362.376545
```
This avoids clock drift issues with TLS certificate verification and Git commit timestamps.

### b. Network Resolver Setup
The resolver configuration is initialized pointing to the host gateway (`192.168.0.1`), verified using `socat`:
```bash
echo nameserver 192.168.0.1 > /etc/resolv.conf
timeout 1s socat /dev/null TCP4:devbox-gateway.internal:53
timeout 1s socat /dev/null TCP4:192.168.0.1:8080
```

### c. Host Git Credential Interception
To securely authenticate against private or public repositories without injecting long-lived GitHub personal access tokens or SSH private keys into the guest, the orchestrator configures Git URL redirection via global config:
```bash
git config --global user.name "google-labs-jules[bot]"
git config --global user.email "161369871+google-labs-jules[bot]@users.noreply.github.com"
git config --global --add url.http://git@192.168.0.1:8080/.insteadOf https://github.com/
git config --global --add url.http://git@192.168.0.1:8080/.insteadOf git@github.com:
git config --global core.hooksPath /dev/null
```
All GitHub requests route transparently through the host Python proxy on `192.168.0.1:8080` which injects ephemeral OAuth tokens.

### d. Repository Cloning into `/app`
The workspace `/app` is wiped, recreated, and assigned to UID 1001 (`jules`):
```bash
sudo rm -rf /app
sudo mkdir /app
sudo chown 1001 /app
git clone --depth 1 --shallow-submodules --no-single-branch --recursive https://github.com/<owner>/<repo> -b main /app
git config --global --remove url.http://git@192.168.0.1:8080/
```
The workspace branch is immediately switched to a task-specific branch:
```bash
git switch -c jules-<task_id>-<hash>
```

### e. Persistent Tmux Session Setup
A headless tmux session named `default` is spawned to host execution:
```bash
tmux new-session -d -s 'default' -c /app -e JULES_SESSION_ID=<task_id> -e GIT_TERMINAL_PROMPT=0 && tmux set-option remain-on-exit on
```
This isolates the agent's interactive subshell from unexpected connection drops over the VSOCK link.

### f. Non-Interactive FIFO Command Routing
The host orchestration agent (`swebot`) transfers instructions to `/run/devbox-session/default/`:
* `command`: Contains the bash commands or script payload.
* `stdin`: Piped input for commands.
* `stdout` / `stderr`: Outputs captured from the subshell execution.

### g. Completion Signaling
The execution harness loads the command into the tmux buffer and executes it with an augmented `PROMPT_COMMAND`:
```bash
COMMAND='PROMPT_COMMAND='\''__CODExx__=$?; echo $__CODExx__ > /run/devbox-session/default/exit_code && touch /run/devbox-session/default/stamp; unset PROMPT_COMMAND;'\''; source /run/devbox-session/default/command < /run/devbox-session/default/stdin > /run/devbox-session/default/stdout 2> /run/devbox-session/default/stderr; __CODExx__=$?; if ! [[ -f /run/devbox-session/default/stamp ]]; then echo $__CODExx__ > /run/devbox-session/default/exit_code; touch /run/devbox-session/default/stamp; fi'
```
A background process runs `inotifywait -e create,moved_to --include /stamp$ /run/devbox-session/default` to immediately detect when the command terminates.

### h. Post-Command Diff Harvesting
Following turn execution, the orchestrator inspects the working tree diffs:
```bash
git diff <base_commit> --diff-filter=AM --name-only
echo "---SEPARATOR---"
git ls-files --others --exclude-standard
```
This allows the orchestrator to track modifications, additions, and deletions made during the turn.

### i. Turn Finish and Firecracker vCPU Pause
When a turn finishes and output is returned to the model reasoning engine, Firecracker suspends the vCPUs (`state: Paused`). Upon resumption for the next turn, kernel dmesg records:
```text
random: crng reseeded due to virtual machine fork
```
confirming snapshot or pause/resume virtualization lifecycle boundaries.
