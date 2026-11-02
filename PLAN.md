# PLAN — warnify: Privileged Journal Warning Monitor & Desktop Notifier

## Governing Documents

This plan follows the project standards defined in [AGENTS.md](AGENTS.md), [ROADMAP.md](ROADMAP.md), and [CHANGELOG.md](CHANGELOG.md).
Only mark an item complete (`[x]`) when it is verifiable from code, automated tests, or deployed benchmark state.

---

## Plan Status Convention

- `[ ]` — Pending task or subtask
- `[~]` — Active task currently being executed
- `[x]` — Verified completed task with concrete evidence
- `Status: ...` — Plain-text indicator of current execution state

---

## Objective & Mission-Critical Imperatives

1. Build a robust, standalone Bash automation utility (`warnify.sh`) that monitors systemd journal logs for events of level `warning` or higher (`journalctl -b -p 0..4`).
2. Maintain persistent cursor and boot state (`/var/lib/warnify/cursor`, `/var/lib/warnify/boot_id`) to guarantee zero duplicate alerts across periodic checks.
3. Automatically detect system startup (uptime < 2 minutes or first run of a new boot session) and perform a comprehensive boot-sweep scanning all warnings/errors from boot time to current time.
4. Deliver rich desktop notifications (`notify-send -u critical`) to the active user's desktop session featuring a penguin/tux icon, precise timestamp, log origin tag (`[Kernel]`, `[systemd]`, etc.), and an interactive `Open` action button.
5. Provide an interactive privileged viewer in `xfce4-terminal` via `pkexec` when the user clicks `Open`, ensuring explicit PolicyKit authorization for accessing privileged system logs.
6. Restrict periodic scans to every 2 minutes with a 3-minute bounded window (`--since="3 minutes ago"` + `--after-cursor`) to avoid querying historical journal entries repeatedly.
7. Provide automatic startup and 2-minute scheduling via generated systemd service and timer units (`warnify.service`, `warnify.timer` with `OnBootSec=1min`, `OnUnitActiveSec=2min`).
8. Ship a 100% passing automated test suite (`test_warnify.sh`) validating all execution modes.

---

## Invariants & Architectural Contract

- **INV-01 (Privilege Boundary):** Background inspection runs with root privileges via systemd timer or sudo, while desktop notifications are dispatched into the active desktop session via DBus (`DBUS_SESSION_BUS_ADDRESS`). Viewing log context interactively triggers `pkexec` inside `xfce4-terminal`.
- **INV-02 (Stateful Cursor & Boot Tracking):** Log inspection must track cursor and boot ID state to detect system reboots and prevent notification spam.
- **INV-03 (Boot Sweep vs Windowed Incremental):** When uptime < 2 min or a new boot session is detected, run a comprehensive boot sweep (`journalctl -b -p 0..4`). For routine runs, scan only the last 2min+buffer (`--since="3 minutes ago"`) combined with cursor tracking.
- **INV-04 (Zero External CDN / 100% Local):** All icons, scripts, units, and documentation are entirely self-contained within the repository.
- **INV-05 (Defensive Shell Standards):** All bash scripts must employ `set -euo pipefail`, handle missing commands gracefully, validate arguments, and pass `bash -n`.
- **INV-06 (Go / Bubble Tea Complexity Threshold):** If concurrency, complex event filtering, or interactive TUI requirements exceed clean Bash maintainability (500+ lines), recommend migration to a compiled Go application (`charmbracelet/bubbletea` + `lipgloss`).

---

## Current Verified State

- [x] Initialized standalone Git repository at `/home/lenin/github/warnify` on branch `main`.
- [x] Applied initial companion files: `AGENTS.md`, `README.md`, `ROADMAP.md`, `CHANGELOG.md`, `HANDOFF.md`, `ISSUES.md`, `VERSION.md` (v0.2.0), `VERSION_GUIDE.md`, `GUM_README.md`, `.env.example`, and `.gitignore`.
- [x] Copied offline penguin icon assets (`assets/penguin.png`, `assets/penguin.svg`).
- [x] Implemented executable `warnify.sh` supporting `--dry-run`, `--once`, `--daemon`, `--boot-sweep`, `--cursor-file`, `--state-dir`, `--priority`, `--install-systemd`, `--uninstall-systemd`, `--status`, and `--view`.
- [x] Created `test_warnify.sh` with 23 passing automated tests covering all syntax, boot-sweep, classification, persistence, and unit definitions.
- [x] Created systemd units `systemd/warnify.service` and `systemd/warnify.timer` (`OnBootSec=1min`, `OnUnitActiveSec=2min`) and verified via `systemd-analyze verify`.
- [x] Created symlink `/home/lenin/.local/bin/,warnify.sh` -> `/home/lenin/github/warnify/warnify.sh`.

---

## Actionable Versions and Subtasks

## 0.1.0 — Initial MVP: Privileged Monitor, Desktop Notifier, and Terminal Viewer
Status: Completed and verified

### 0.1.1 — CLI Scaffolding & Automated Test Harness
- [x] Task: Create executable script skeleton and automated test runner
  - [x] **Step 1:** Author `test_warnify.sh` validating CLI flags (`--help`, `--version`, `--dry-run`, `--once`, `--cursor-file`, invalid flags) and exit codes.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`
  - [x] **Step 2:** Implement argument parsing, help text, version output, and dry-run dispatch in `warnify.sh`.
    - File: `warnify.sh`
    - Command: `bash -n warnify.sh && ./test_warnify.sh`

### 0.1.2 — Journal Inspection & Stateful Cursor Deduplication
- [x] Task: Implement log inspection using `journalctl` JSON output and stateful cursor tracking
  - [x] **Step 1:** Implement `query_journal()` in `warnify.sh` reading `journalctl -b -p 0..4 -o json` with `--cursor-file`.
    - File: `warnify.sh`
    - Command: `./warnify.sh --dry-run`
  - [x] **Step 2:** Parse log records to extract timestamp, severity level, message text, and origin category (`[Kernel]`, `[systemd]`, `[syslog]`).
    - File: `warnify.sh`
    - Command: `bash test_warnify.sh`
  - [x] **Step 3:** Add unit tests in `test_warnify.sh` verifying deduplication against simulated cursor files.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`

### 0.1.3 — Desktop Session Notification Dispatcher
- [x] Task: Implement DBus desktop notification delivery with penguin icon and action button
  - [x] **Step 1:** Implement session detection (`detect_active_session()`) to resolve target GUI user, DBUS socket, and DISPLAY.
    - File: `warnify.sh`
    - Command: `./test_warnify.sh`
  - [x] **Step 2:** Implement `dispatch_notification()` using `notify-send -u critical -i assets/penguin.png -A open="Open Log"`.
    - File: `warnify.sh`
    - Command: `./test_warnify.sh`
  - [x] **Step 3:** Implement flood protection batching multiple events in the same cycle into a summary notification.
    - File: `warnify.sh`
    - Command: `./test_warnify.sh`

### 0.1.4 — Interactive Privileged Viewer Integration
- [x] Task: Connect notification action callback to `xfce4-terminal` with `pkexec`
  - [x] **Step 1:** Implement action handler in `warnify.sh` that triggers `xfce4-terminal -T "warnify: System Warning Details" -e "pkexec journalctl --cursor=... -n 50 -xb"`.
    - File: `warnify.sh`
    - Command: `./test_warnify.sh`
  - [x] **Step 2:** Test action callback launch command formatting and error handling in `test_warnify.sh`.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`

### 0.1.5 — Systemd 1-Minute Timer & Service Unit Automation
- [x] Task: Implement systemd timer and service unit generators
  - [x] **Step 1:** Create `systemd/warnify.service` and `systemd/warnify.timer` (`OnCalendar=*:0/1`).
    - File: `systemd/warnify.service`, `systemd/warnify.timer`
    - Command: `systemd-analyze verify systemd/warnify.*`
  - [x] **Step 2:** Add `--install-systemd` and `--status` commands to `warnify.sh` to install, enable, and inspect the timer.
    - File: `warnify.sh`
    - Command: `./test_warnify.sh`

### 0.1.6 — Symlinking, Final Verification & Documentation
- [x] Task: Complete end-to-end verification and documentation
  - [x] **Step 1:** Create local user symlink `~/.local/bin/,warnify.sh` pointing to `/home/lenin/github/warnify/warnify.sh`.
    - File: `~/.local/bin/,warnify.sh`
    - Command: `ls -l ~/.local/bin/,warnify.sh`
  - [x] **Step 2:** Run full automated test suite and record clean pass.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`
  - [x] **Step 3:** Update `CHANGELOG.md` with v0.1.0 release notes and update root `/home/lenin/github/talanovdb-mini/CHANGELOG.md`.
    - File: `CHANGELOG.md`, `/home/lenin/github/talanovdb-mini/CHANGELOG.md`
    - Command: `git status`

---

## 0.2.0 — Boot-Sweep Mode, 2-Minute Cadence, and Windowed Incremental Scans
Status: Completed and verified

### 0.2.1 — Startup Detection & Comprehensive Boot-Sweep
- [x] Task: Implement system uptime & boot session detection with comprehensive boot warning sweep
  - [x] **Step 1:** Implement `is_boot_sweep_needed()` in `warnify.sh` checking `/proc/uptime` (< 120s) and `/proc/sys/kernel/random/boot_id`.
    - File: `warnify.sh`
    - Command: `bash -n warnify.sh`
  - [x] **Step 2:** When boot sweep is triggered, scan `journalctl -b -p 0..4` from boot start (omitting `--since`), generate boot-specific notification, and persist boot ID.
    - File: `warnify.sh`
    - Command: `./warnify.sh --dry-run --boot-sweep`
  - [x] **Step 3:** Add unit test in `test_warnify.sh` validating boot detection logic and boot sweep reporting.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`

### 0.2.2 — 2-Minute Windowed Scan Cadence
- [x] Task: Implement 2-minute incremental scan window (`--since="3 minutes ago"` + `--after-cursor`)
  - [x] **Step 1:** For routine runs (uptime >= 120s and current boot registered), restrict query to `--since="3 minutes ago"` combined with `--after-cursor`.
    - File: `warnify.sh`
    - Command: `./warnify.sh --dry-run`
  - [x] **Step 2:** Update test harness in `test_warnify.sh` to verify windowed query arguments.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`

### 0.2.3 — Systemd Startup & 2-Minute Timer Configuration
- [x] Task: Update systemd units for boot startup and 2-minute periodic execution
  - [x] **Step 1:** Update `systemd/warnify.timer` and `warnify.sh` templates with `OnBootSec=1min` and `OnUnitActiveSec=2min`.
    - File: `systemd/warnify.timer`, `warnify.sh`
    - Command: `systemd-analyze verify systemd/warnify.service systemd/warnify.timer`
  - [x] **Step 2:** Update tests in `test_warnify.sh` asserting `OnBootSec=1min` and `OnUnitActiveSec=2min`.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`

### 0.2.4 — Verification, Documentation & Release Bump
- [x] Task: Complete verification and release documentation
  - [x] **Step 1:** Update `README.md` documenting boot-sweep mode and 2-minute interval.
    - File: `README.md`
    - Command: `git diff README.md`
  - [x] **Step 2:** Run full automated test suite `test_warnify.sh` ensuring all tests pass.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`
  - [x] **Step 3:** Update `CHANGELOG.md` with Keep a Changelog entries for v0.2.0 and update root `/home/lenin/github/talanovdb-mini/CHANGELOG.md`.
    - File: `CHANGELOG.md`, `/home/lenin/github/talanovdb-mini/CHANGELOG.md`
    - Command: `git status`

---

## 0.2.1 — Bash Triage: Boot Detection Hotfix, Streaming JQ Parser, and Test Stabilization
Status: Completed and verified

### 0.2.1.1 — Boot ID Detection & Character Parsing Hotfix
- [x] Task: Fix `tr` argument syntax error in boot ID parsing
  - [x] **Step 1:** Replace `tr -d '-\n\r '` with `tr -d '[:space:]-'` in `get_current_boot_id()` and `is_boot_sweep_needed()`.
    - File: `warnify.sh`
    - Command: `./warnify.sh --status`
  - [x] **Step 2:** Add assertion in `test_warnify.sh` ensuring `Current boot ID:` never resolves to `"unknown"`.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`

### 0.2.1.2 — Single-Pass Streaming JQ Parser
- [x] Task: Eliminate the 200,000+ process fork loop in `scan_journal()`
  - [x] **Step 1:** Refactor `scan_journal()` to stream `journalctl` directly into a single `jq -s` pipeline.
    - File: `warnify.sh`
    - Command: `./warnify.sh --dry-run`
  - [x] **Step 2:** Cap boot sweep journal extraction to `-n 1000` to prevent memory spikes on long-running systems.
    - File: `warnify.sh`
    - Command: `./warnify.sh --boot-sweep --dry-run`
  - [x] **Step 3:** Aggregate top-5 category counts to prevent notification buffer bloat.
    - File: `warnify.sh`
    - Command: `./warnify.sh --dry-run`

### 0.2.1.3 — Test Suite & Release Verification
- [x] Task: Verify test suite execution and bump release metadata
  - [x] **Step 1:** Update `test_warnify.sh` and verify all 24 tests pass in < 2s.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`
  - [x] **Step 2:** Bump version to `0.2.1` in `VERSION.md`, `warnify.sh`, and `README.md`.
    - File: `VERSION.md`, `warnify.sh`, `README.md`
    - Command: `./warnify.sh --version`
  - [x] **Step 3:** Update `CHANGELOG.md`, `ISSUES.md`, and `HANDOFF.md`.
    - File: `CHANGELOG.md`, `ISSUES.md`, `HANDOFF.md`
    - Command: `git status`

---

## Complexity Assessment & Go Migration Policy

If the script's logic, concurrency, data structures, or state management becomes too complicated for clean Bash maintenance (exceeding 500-1000 lines), transition the project to a compiled **Go** application using `charmbracelet/bubbletea`, `charmbracelet/lipgloss`, and `charmbracelet/bubbles`.

---

## Deferred Items Ledger

| ID | Type | Priority | Description | Containment / Reason | Target |
|---|---|---|---|---|---|
| DEF-001 | Feature | Low | Custom regex ignore filter list for known harmless warnings | Out of scope for initial 0.2.0 | 0.3.0 |
| DEF-002 | Feature | Low | Audio alert chime alongside notify-send | User requested visual desktop notification only | 0.3.0 |
| DEF-003 | Feature | Low | Rich Charm Gum interactive TUI log browser within the opened terminal | Initial releases use direct pkexec journalctl with less pager | 0.3.0 |
