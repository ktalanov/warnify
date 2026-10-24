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
2. Maintain persistent cursor state (`--cursor-file`) to guarantee zero duplicate alerts across periodic checks.
3. Deliver rich desktop notifications (`notify-send -u critical`) to the active user's desktop session featuring a penguin/tux icon, precise timestamp, log origin tag (`[Kernel]`, `[systemd]`, etc.), and an interactive `Open` action button.
4. Provide an interactive privileged viewer in `xfce4-terminal` via `pkexec` when the user clicks `Open`, ensuring explicit PolicyKit authorization for accessing privileged system logs.
5. Provide automatic 1-minute scheduling via generated systemd service and timer units (`warnify.service`, `warnify.timer`).
6. Ship a 100% passing automated test suite (`test_warnify.sh`) validating CLI parsing, JSON log parsing, cursor deduplication, notification payload generation, and systemd unit generation.

---

## Invariants & Architectural Contract

- **INV-01 (Privilege Boundary):** Background inspection runs with root privileges via systemd timer or sudo, while desktop notifications are dispatched into the active desktop session via DBus (`DBUS_SESSION_BUS_ADDRESS`). Viewing log context interactively triggers `pkexec` inside `xfce4-terminal`.
- **INV-02 (Stateful Cursor Tracking):** Log inspection must use `journalctl --cursor-file` or cursor persistence in `/var/lib/warnify/cursor` (or user-configurable path) to prevent notification spam across 1-minute intervals.
- **INV-03 (Notification Flood Protection):** Multiple warnings occurring within the same 1-minute interval must be batched into a single summary notification with origin breakdown and an `Open` button.
- **INV-04 (Zero External CDN / 100% Local):** All icons, scripts, units, and documentation are entirely self-contained within the repository.
- **INV-05 (Defensive Shell Standards):** All bash scripts must employ `set -euo pipefail`, handle missing commands gracefully, validate arguments, and pass `shellcheck` and `bash -n`.
- **INV-06 (Go / Bubble Tea Complexity Threshold):** If concurrency, complex event filtering, or interactive TUI requirements exceed clean Bash maintainability (500+ lines), recommend migration to a compiled Go application (`charmbracelet/bubbletea` + `lipgloss`).

---

## Current Verified State

- [x] Initialized standalone Git repository at `/home/lenin/github/warnify` on branch `main`.
- [x] Applied initial companion files: `AGENTS.md`, `README.md`, `ROADMAP.md`, `CHANGELOG.md`, `HANDOFF.md`, `ISSUES.md`, `VERSION.md` (v0.1.0), `VERSION_GUIDE.md`, `GUM_README.md`, `.env.example`, and `.gitignore`.
- [x] Copied offline penguin icon assets (`assets/penguin.png`, `assets/penguin.svg`).
- [x] Implemented executable `warnify.sh` supporting `--dry-run`, `--once`, `--cursor-file`, `--priority`, `--install-systemd`, `--uninstall-systemd`, `--status`, and `--view`.
- [x] Created `test_warnify.sh` covering syntax, arguments, dry-run, JSON event classification, cursor persistence, and systemd templates.
- [x] Verified 16/16 tests pass in `test_warnify.sh`.
- [x] Created systemd units `systemd/warnify.service` and `systemd/warnify.timer` (`OnCalendar=*:0/1`) and verified via `systemd-analyze verify`.
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

## Complexity Assessment & Go Migration Policy

If the script's logic, concurrency, data structures, or state management becomes too complicated for clean Bash maintenance (exceeding 500-1000 lines), transition the project to a compiled **Go** application using `charmbracelet/bubbletea`, `charmbracelet/lipgloss`, and `charmbracelet/bubbles`.

---

## Deferred Items Ledger

| ID | Type | Priority | Description | Containment / Reason | Target |
|---|---|---|---|---|---|
| DEF-001 | Feature | Low | Custom regex ignore filter list for known harmless warnings | Out of scope for initial 0.1.0 MVP | 0.2.0 |
| DEF-002 | Feature | Low | Audio alert chime alongside notify-send | User requested visual desktop notification only | 0.2.0 |
| DEF-003 | Feature | Low | Rich Charm Gum interactive TUI log browser within the opened terminal | Initial MVP uses direct pkexec journalctl with less pager | 0.2.0 |
