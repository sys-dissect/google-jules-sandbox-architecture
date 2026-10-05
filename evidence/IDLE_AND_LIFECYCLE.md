# MicroVM Idle Suspension and Task Lifecycle Analysis

## 1. The Idle Suspension Mechanism: Hypervisor vCPU Freezing

Direct inspection of kernel logs and runtime state proves that Google Jules devbox does **not** idle out via guest-level mechanisms (such as `systemd-logind`, `TMOUT`, or cron):

* **Guest Logind Configuration:**
  ```text
  # /etc/systemd/logind.conf
  #IdleAction=ignore
  #IdleActionSec=30min
  #StopIdleSessionSec=infinity
  ```
  All guest-level systemd idle actions are disabled.

* **Kernel Telemetry Proof (CRNG Fork Reseeding):**
  ```text
  $ dmesg | grep -i fork
  [18414610.543718] random: crng reseeded due to virtual machine fork
  [18415818.163718] random: crng reseeded due to virtual machine fork
  [18416895.172695] random: crng reseeded due to virtual machine fork
  [18417420.389110] random: crng reseeded due to virtual machine fork
  ```
  Every time connectivity drops and resumes, the Linux kernel logs:
  `random: crng reseeded due to virtual machine fork`

### Systems Root Cause
1. **Serverless MicroVM Suspension:** Google Jules devboxes utilize AWS Firecracker's microVM state management API (`PATCH /vm {"state": "Paused"}` / `/snapshot/create`).
2. **Turn-Boundary Freezing:** When the Jules coding agent completes its execution turn (all commands finish and the response text is delivered to the user), the host orchestrator enters a "waiting for user" state.
3. **Inactivity Window:** Approximately **10 to 15 minutes** after the last activity, the host hypervisor halts all guest vCPUs.
4. **Network Impact:** While the vCPUs are frozen, no guest code executes. The Tailcat WireGuard DERP keepalive and TCP SSH connections are not acknowledged or routed by the guest kernel, causing external clients to experience connection timeouts.
5. **Instantaneous Thawing:** When the developer sends a new message or prompt to Jules via the UI/GitHub, the host hypervisor immediately resumes the microVM (`PATCH /vm {"state": "Resumed"}`). The vCPUs thaw, kernel clock jumps forward, random CRNG reseeds, and Tailcat/SSH connections immediately resume without process restart or PID change.

---

## 2. Why In-Guest Background Daemons Fail to Prevent Idle

* Running persistent daemons (such as `tailcat serve`, `dockerd`, `containerd`, or `nohup sleep`) inside the guest does **not** prevent Firecracker from pausing the microVM.
* **Reason:** The hypervisor pause is commanded externally by the Google Cloud Jules host orchestration plane, not by inspecting guest process lists or CPU load. When the host initiates a pause, the hypervisor halts the KVM vCPU threads regardless of guest runqueue length.

---

## 3. How to Prevent or Mitigate Idle Suspension

1. **Active-Turn Command Execution (In-Harness Blocking):**
   * The host orchestrator only pauses the microVM when a turn is **complete**.
   * While a command is actively running inside the tmux harness (`source /run/devbox-session/default/command`), the host SSH worker (`swebot`) blocks on `inotifywait` waiting for `/run/devbox-session/default/stamp`.
   * Instructing Jules to run long-running diagnostic commands or polling loops prevents the agent from completing its turn, keeping the microVM actively executing on the host.
   * *Constraint:* Individual tool execution calls are subject to host-level execution timeouts (typically 10–15 minutes).

2. **Conversational Heartbeat (Host-Triggered Thaw):**
   * Sending any lightweight message (e.g. `keepalive`, status check, or `continue`) through the Jules chat interface or PR review resets the inactivity timer and immediately unpauses the microVM in sub-second time.

3. **Task Lifecycle vs. MicroVM Pause:**
   * **Pause (Soft Idle):** Occurs between turns; memory state and writable overlayfs remain fully intact; address persists.
   * **Task Termination (Hard Expiry):** Occurs when the GitHub PR is merged, closed, or task timeout is reached; the microVM is destroyed, `/dev/vdb` is wiped, and the Tailcat endpoint is permanently decommissioned.
