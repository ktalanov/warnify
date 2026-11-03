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

1. Build a robust, privileged Linux system monitoring utility that tracks systemd journal logs for events of level `warning` or higher (`journalctl -b -p 0..4`).
2. Maintain persistent cursor and boot state (`/var/lib/warnify/cursor`, `/var/lib/warnify/boot_id`) to guarantee zero duplicate alerts across periodic checks.
3. Automatically detect system startup (uptime < 2 minutes or first run of a new boot session) and perform a comprehensive boot-sweep scanning all warnings/errors from boot time to current time.
4. Deliver rich desktop notifications (`notify-send -u critical` or native DBus) to the active user's desktop session featuring a penguin/tux icon, precise timestamp, log origin tag (`[Kernel]`, `[systemd]`, etc.), and an interactive `Open` action button.
5. Provide an interactive privileged viewer (transitioning from `xfce4-terminal -e pkexec journalctl` to an embedded Charm Bubble Tea TUI) when the user clicks `Open`.
6. Restrict periodic scans to every 2 minutes with a 3-minute bounded window (`--since="3 minutes ago"` + `--after-cursor`) to avoid querying historical journal entries repeatedly.
7. Provide automatic startup and 2-minute scheduling via generated systemd service and timer units (`warnify.service`, `warnify.timer` with `OnBootSec=1min`, `OnUnitActiveSec=2min`).
8. Maintain a 100% passing automated test suite (`test_warnify.sh` and future Go unit tests) validating all execution modes.
9. Support configurable noise reduction via regular expression ignore patterns to eliminate repetitive harmless log noise.
10. Execute a disciplined migration from Bash to a compiled Go binary once configuration and filtering contracts are stabilized.

---

## Invariants & Architectural Contract

- **INV-01 (Privilege Boundary):** Background inspection runs with root privileges via systemd timer, daemon, or sudo, while desktop notifications are dispatched into the active desktop session via DBus (`DBUS_SESSION_BUS_ADDRESS`). Viewing log context interactively triggers PolicyKit elevation (`pkexec`).
- **INV-02 (Stateful Cursor & Boot Tracking):** Log inspection must track cursor and boot ID state to detect system reboots and prevent notification spam.
- **INV-03 (Boot Sweep vs Windowed Incremental):** When uptime < 2 min or a new boot session is detected, run a comprehensive boot sweep (`journalctl -b -p 0..4` capped to 1000 records). For routine runs, scan only the last 2min+buffer (`--since="3 minutes ago"`) combined with cursor tracking.
- **INV-04 (Zero External CDN / 100% Local):** All icons, scripts, units, reports, and documentation are entirely self-contained within the repository.
- **INV-05 (Defensive Shell Standards):** All bash scripts must employ `set -euo pipefail`, handle missing commands gracefully, validate arguments, and pass `bash -n`.
- **INV-06 (Go / Bubble Tea Complexity Threshold & Migration Invariant):** If concurrency, complex event filtering, or interactive TUI requirements exceed clean Bash maintainability (500+ lines), transition the core application to a compiled **Go** application (`charmbracelet/bubbletea` + `lipgloss` + `coreos/go-systemd`).

---

## Current Verified State

- [x] Initialized standalone Git repository at `/home/lenin/github/warnify` on branch `main`.
- [x] Applied complete companion files: `AGENTS.md`, `README.md`, `ROADMAP.md`, `CHANGELOG.md`, `HANDOFF.md`, `ISSUES.md`, `VERSION.md` (v0.2.1), `VERSION_GUIDE.md`, `GUM_README.md`, `.env.example`, and `.gitignore`.
- [x] Connected to GitHub remote `https://github.com/ktalanov/warnify.git` and configured upstream tracking for `main`.
- [x] Established GitHub Cross-Model Synchronization Ledgers:
  - Global Sync: [Issue #1 (`sync-global`, `sync`)](https://github.com/ktalanov/warnify/issues/1)
  - Version Sync v0.2.1: [Issue #2 (`sync`)](https://github.com/ktalanov/warnify/issues/2)
- [x] Copied offline penguin icon assets (`assets/penguin.png`, `assets/penguin.svg`).
- [x] Implemented executable `warnify.sh` supporting `--dry-run`, `--once`, `--daemon`, `--boot-sweep`, `--cursor-file`, `--state-dir`, `--priority`, `--install-systemd`, `--uninstall-systemd`, `--status`, and `--view`.
- [x] Completed v0.2.1 triage fixes:
  - Fixed POSIX `tr` character class syntax (`tr -d '[:space:]-'`) so boot IDs resolve to valid UUIDs instead of `"unknown"`.
  - Replaced O(N) process fork loop with unified streaming `jq -s` pipeline, reducing 28k-event scan time from 60+ minutes to 1.2s.
  - Capped historical boot-sweep scan to `-n 1000` to prevent memory bloat on workstations running for weeks.
  - Aggregated top-5 category summary in desktop notifications.
- [x] Created `test_warnify.sh` with 24 passing automated tests covering syntax, boot-sweep, classification, persistence, status, and UUID assertions.
- [x] Created systemd units `systemd/warnify.service` and `systemd/warnify.timer` (`OnBootSec=1min`, `OnUnitActiveSec=2min`) and verified via `systemd-analyze verify`.
- [x] Created symlink `/home/lenin/.local/bin/,warnify.sh` -> `/home/lenin/github/warnify/warnify.sh`.
- [x] Archived visual diagnosis dossier in `reports/11-03-26-warnify-operational-readiness-report.md`.

---

## Actionable Versions and Subtasks

## 0.1.0 — Initial MVP: Privileged Monitor, Desktop Notifier, and Terminal Viewer
Status: Completed and verified

### 0.1.1 — CLI Scaffolding & Automated Test Harness
- [x] Task: Create executable script skeleton and automated test runner
  - [x] **Step 1:** Author `test_warnify.sh` validating CLI flags (`--help`, `--version`, `--dry-run`, `--once`, `--cursor-file`, invalid flags) and exit codes.
  - [x] **Step 2:** Implement argument parsing, help text, version output, and dry-run dispatch in `warnify.sh`.

### 0.1.2 — Journal Inspection & Stateful Cursor Deduplication
- [x] Task: Implement log inspection using `journalctl` JSON output and stateful cursor tracking
  - [x] **Step 1:** Implement `query_journal()` in `warnify.sh` reading `journalctl -b -p 0..4 -o json` with `--cursor-file`.
  - [x] **Step 2:** Parse log records to extract timestamp, severity level, message text, and origin category (`[Kernel]`, `[systemd]`, `[syslog]`).
  - [x] **Step 3:** Add unit tests in `test_warnify.sh` verifying deduplication against simulated cursor files.

### 0.1.3 — Desktop Session Notification Dispatcher
- [x] Task: Implement DBus desktop notification delivery with penguin icon and action button
  - [x] **Step 1:** Implement session detection (`detect_active_session()`) to resolve target GUI user, DBUS socket, and DISPLAY.
  - [x] **Step 2:** Implement `dispatch_notification()` using `notify-send -u critical -i assets/penguin.png -A open="Open Log"`.
  - [x] **Step 3:** Implement flood protection batching multiple events in the same cycle into a summary notification.

### 0.1.4 — Interactive Privileged Viewer Integration
- [x] Task: Connect notification action callback to `xfce4-terminal` with `pkexec`
  - [x] **Step 1:** Implement action handler in `warnify.sh` that triggers `xfce4-terminal -T "warnify: System Warning Details" -e "pkexec journalctl --cursor=... -n 50 -xb"`.
  - [x] **Step 2:** Test action callback launch command formatting and error handling in `test_warnify.sh`.

### 0.1.5 — Systemd 1-Minute Timer & Service Unit Automation
- [x] Task: Implement systemd timer and service unit generators
  - [x] **Step 1:** Create `systemd/warnify.service` and `systemd/warnify.timer` (`OnCalendar=*:0/1`).
  - [x] **Step 2:** Add `--install-systemd` and `--status` commands to `warnify.sh` to install, enable, and inspect the timer.

### 0.1.6 — Symlinking, Final Verification & Documentation
- [x] Task: Complete end-to-end verification and documentation
  - [x] **Step 1:** Create local user symlink `~/.local/bin/,warnify.sh` pointing to `/home/lenin/github/warnify/warnify.sh`.
  - [x] **Step 2:** Run full automated test suite and record clean pass.
  - [x] **Step 3:** Update `CHANGELOG.md` with v0.1.0 release notes.

---

## 0.2.0 — Boot-Sweep Mode, 2-Minute Cadence, and Windowed Incremental Scans
Status: Completed and verified

### 0.2.1 — Startup Detection & Comprehensive Boot-Sweep
- [x] Task: Implement system uptime & boot session detection with comprehensive boot warning sweep
  - [x] **Step 1:** Implement `is_boot_sweep_needed()` in `warnify.sh` checking `/proc/uptime` (< 120s) and `/proc/sys/kernel/random/boot_id`.
  - [x] **Step 2:** When boot sweep is triggered, scan `journalctl -b -p 0..4` from boot start (omitting `--since`), generate boot-specific notification, and persist boot ID.
  - [x] **Step 3:** Add unit test in `test_warnify.sh` validating boot detection logic and boot sweep reporting.

### 0.2.2 — 2-Minute Windowed Scan Cadence
- [x] Task: Implement 2-minute incremental scan window (`--since="3 minutes ago"` + `--after-cursor`)
  - [x] **Step 1:** For routine runs (uptime >= 120s and current boot registered), restrict query to `--since="3 minutes ago"` combined with `--after-cursor`.
  - [x] **Step 2:** Update test harness in `test_warnify.sh` to verify windowed query arguments.

### 0.2.3 — Systemd Startup & 2-Minute Timer Configuration
- [x] Task: Update systemd units for boot startup and 2-minute periodic execution
  - [x] **Step 1:** Update `systemd/warnify.timer` and `warnify.sh` templates with `OnBootSec=1min` and `OnUnitActiveSec=2min`.
  - [x] **Step 2:** Update tests in `test_warnify.sh` asserting `OnBootSec=1min` and `OnUnitActiveSec=2min`.

### 0.2.4 — Verification, Documentation & Release Bump
- [x] Task: Complete verification and release documentation
  - [x] **Step 1:** Update `README.md` documenting boot-sweep mode and 2-minute interval.
  - [x] **Step 2:** Run full automated test suite `test_warnify.sh` ensuring all tests pass.
  - [x] **Step 3:** Update `CHANGELOG.md` with Keep a Changelog entries for v0.2.0.

---

## 0.2.1 — Bash Triage: Boot Detection Hotfix, Streaming JQ Parser, and Test Stabilization
Status: Completed and verified

### 0.2.1.1 — Boot ID Detection & Character Parsing Hotfix
- [x] Task: Fix `tr` argument syntax error in boot ID parsing
  - [x] **Step 1:** Replace `tr -d '-\n\r '` with `tr -d '[:space:]-'` in `get_current_boot_id()` and `is_boot_sweep_needed()`.
  - [x] **Step 2:** Add assertion in `test_warnify.sh` ensuring `Current boot ID:` never resolves to `"unknown"`.

### 0.2.1.2 — Single-Pass Streaming JQ Parser
- [x] Task: Eliminate the 200,000+ process fork loop in `scan_journal()`
  - [x] **Step 1:** Refactor `scan_journal()` to stream `journalctl` directly into a single `jq -s` pipeline.
  - [x] **Step 2:** Cap boot sweep journal extraction to `-n 1000` to prevent memory spikes on long-running systems.
  - [x] **Step 3:** Aggregate top-5 category counts to prevent notification buffer bloat.

### 0.2.1.3 — Test Suite & Release Verification
- [x] Task: Verify test suite execution and bump release metadata
  - [x] **Step 1:** Update `test_warnify.sh` and verify all 24 tests pass in < 2s.
  - [x] **Step 2:** Bump version to `0.2.1` in `VERSION.md`, `warnify.sh`, and `README.md`.
  - [x] **Step 3:** Update `CHANGELOG.md`, `ISSUES.md`, and `HANDOFF.md`.

---

## 0.3.0 — Regex Ignore Filtering, Burst Cooldown & Audio Alerts (Bash Contract Stabilization)
Status: Pending

### 0.3.1 — Configurable Regular Expression Ignore Filter
- [ ] Task: Implement pattern suppression configuration files
  - [ ] **Step 1:** Design configuration parser for `/etc/warnify/ignore.conf` (system-wide) and `~/.config/warnify/ignore.conf` (user overrides).
    - File: `warnify.sh`, `systemd/ignore.conf.example`
    - Acceptance: Lines starting with `#` are ignored; non-empty lines are compiled into an ignore filter regex pattern.
  - [ ] **Step 2:** Integrate regex exclusion into `scan_journal()`'s `jq` parser or pre-filter stage.
    - File: `warnify.sh`
    - Acceptance: Log events matching ignore patterns are suppressed from notifications and counts, but cursor advances normally.
  - [ ] **Step 3:** Add CLI flag `--ignore-file <FILE>` to override config location.
    - File: `warnify.sh`
    - Acceptance: Custom file path verified during dry-run.
  - [ ] **Step 4:** Author automated tests in `test_warnify.sh` validating pattern suppression.
    - File: `test_warnify.sh`
    - Command: `./test_warnify.sh`

### 0.3.2 — Sliding-Window Burst Deduplication & Per-Source Cooldown
- [ ] Task: Throttle repetitive notification alerts for chronic errors
  - [ ] **Step 1:** Maintain an in-memory or statefile hash table of recently alerted sources and timestamps.
    - File: `warnify.sh`
    - Acceptance: If identical source alerts >3 times within 10 minutes, throttle subsequent desktop alerts and summarize in cooldown note.
  - [ ] **Step 2:** Add CLI flag `--cooldown-secs <N>` (default: 300s).
    - File: `warnify.sh`
  - [ ] **Step 3:** Author automated tests in `test_warnify.sh` validating cooldown throttling.
    - File: `test_warnify.sh`

### 0.3.3 — Optional Desktop Audio Alert Chime
- [ ] Task: Add non-blocking sound notification
  - [ ] **Step 1:** Implement `--sound` flag and detect system audio players (`paplay`, `pw-play`, `aplay`, `canberra-gtk-play`).
    - File: `warnify.sh`
    - Acceptance: Plays subtle system alert sound asynchronously when critical alert fires.
  - [ ] **Step 2:** Add unit tests in `test_warnify.sh` checking sound flag parsing and fallback behavior.

---

## 0.4.0 — Go Core Transition: Native Journal Access & DBus Daemon
Status: Pending

### 0.4.1 — Go Project Scaffolding & Architecture
- [ ] Task: Initialize Go module and package structure
  - [ ] **Step 1:** Initialize `go.mod` (`module github.com/ktalanov/warnify`) targeting Go 1.22+.
    - Files: `go.mod`, `go.sum`, `cmd/warnify/main.go`
    - Command: `go build -o bin/warnify ./cmd/warnify`
  - [ ] **Step 2:** Implement CLI argument parser using `github.com/spf13/cobra` mirroring all v0.3.0 Bash flags (`--dry-run`, `--boot-sweep`, `--once`, `--daemon`, `--status`, etc.).
    - Files: `internal/config/config.go`, `cmd/warnify/cmd/root.go`
    - Command: `go test ./...`

### 0.4.2 — Native Systemd Journal Integration (sdjournal)
- [ ] Task: Replace subprocess `journalctl` with native journal C-bindings
  - [ ] **Step 1:** Implement journal reader using `github.com/coreos/go-systemd/v22/sdjournal`.
    - Files: `internal/journal/scanner.go`
    - Acceptance: Microsecond event retrieval, native cursor seek, boot filtering, priority matching.
  - [ ] **Step 2:** Port event classification, regex ignore filtering, and timestamp formatting into Go.
    - Files: `internal/journal/filter.go`
    - Acceptance: Unit benchmarks showing <5ms execution over 1000 events.

### 0.4.3 — Pure-Go Freedesktop Notification Dispatcher
- [ ] Task: Implement native DBus desktop notification delivery
  - [ ] **Step 1:** Implement notification dispatcher using `github.com/godbus/dbus/v5` targeting `org.freedesktop.Notifications`.
    - Files: `internal/notify/dispatcher.go`
    - Acceptance: Sends notifications with penguin icon, action callbacks, and priority urgency without shelling out to `notify-send`.
  - [ ] **Step 2:** Implement user session detector querying `org.freedesktop.login1`.
    - Files: `internal/session/detector.go`

### 0.4.4 — Daemon Lifecycle & Watchdog Integration
- [ ] Task: Implement production systemd daemon capabilities
  - [ ] **Step 1:** Implement background ticker and signal handler (`SIGTERM`, `SIGINT`, `SIGHUP` reload).
    - Files: `internal/daemon/daemon.go`
  - [ ] **Step 2:** Add `sd_notify` watchdog support (`WATCHDOG=1`, `READY=1`).
    - Files: `internal/daemon/systemd.go`

---

## 0.5.0 — Interactive Bubble Tea Terminal Log Inspector (TUI)
Status: Pending

### 0.5.1 — Charm Bubble Tea Application Architecture
- [ ] Task: Author dedicated terminal log browser replacing `less` / `pkexec journalctl`
  - [ ] **Step 1:** Implement `warnify view` command built with `charmbracelet/bubbletea` and `charmbracelet/bubbles`.
    - Files: `internal/tui/app.go`, `internal/tui/model.go`
  - [ ] **Step 2:** Implement event table model with live status badge indicators, timestamp formatting, and origin tags styled via `charmbracelet/lipgloss`.
    - Files: `internal/tui/table.go`, `internal/tui/styles.go`

### 0.5.2 — Interactive Filtering & Navigation
- [ ] Task: Add real-time interactive search and category filtering
  - [ ] **Step 1:** Implement real-time fuzzy search across messages and identifiers.
    - Files: `internal/tui/search.go`
  - [ ] **Step 2:** Implement category quick-filter tabs: `All`, `Kernel (dmesg)`, `Services`, `Daemons`.
    - Files: `internal/tui/tabs.go`
  - [ ] **Step 3:** Implement detailed log entry viewer popup displaying full metadata (PID, UID, Unit, CGroup, raw payload) with JSON export.
    - Files: `internal/tui/detail.go`

---

## 1.0.0 — Production MVP Hardening & Packaging
Status: Pending

### 1.0.1 — Multi-Seat Desktop Discovery & Broadcast
- [ ] Task: Deliver notifications across all active graphical user seats
  - [ ] **Step 1:** Enumerate all active X11 and Wayland sessions and dispatch alerts concurrently.
    - Files: `internal/session/multiseat.go`

### 1.0.2 — Packaging & System Distribution
- [ ] Task: Author packaging manifests for standard Linux distributions
  - [ ] **Step 1:** Create RPM spec file for Fedora/RHEL/CentOS (`packaging/rpm/warnify.spec`).
  - [ ] **Step 2:** Create Arch Linux PKGBUILD (`packaging/arch/PKGBUILD`).
  - [ ] **Step 3:** Implement automated GoReleaser configuration (`.goreleaser.yaml`) generating static binary tarballs.

### 1.0.3 — CI/CD Matrix & Documentation
- [ ] Task: Establish automated multi-platform verification
  - [ ] **Step 1:** Create GitHub Actions workflow running tests across Fedora, Ubuntu, and Arch runners.
    - File: `.github/workflows/ci.yml`
  - [ ] **Step 2:** Author manual page `man 1 warnify` and publish v1.0.0 release notes.

---

## Complexity Assessment & Go vs. Rust Migration Policy

### Language Evaluation Matrix

| Metric | Bash (v0.2.1 Current) | Go (`charmbracelet/bubbletea`) | Rust (`ratatui` + `zbus`) |
|---|---|---|---|
| **Lines of Code** | 620 lines (at limit) | ~1,200 lines (modular) | ~1,800 lines (verbose) |
| **Execution Latency** | ~1.2s per scan | **<5ms** per scan | **<2ms** per scan |
| **Memory Footprint** | ~35MB (subshells) | **~6–8MB** RAM | **~2–3MB** RAM |
| **Interactive TUI** | Basic pager (`less`) | **World-class (Bubble Tea)** | High ceremony (Ratatui) |
| **Systemd Binding** | CLI subprocess (`journalctl`) | Native `sdjournal` / CGO | Native `systemd-sys` FFI |
| **DBus Integration** | External `notify-send` | **Pure-Go `godbus/dbus`** | Async `zbus` runtime |
| **Compilation Speed** | Interpreted | **1.5s** incremental | 45–90s release |
| **Binary Size** | Shell script | ~8–12MB static binary | ~3–5MB static binary |

### Strategic Recommendation & Rationale
1. **Language Choice:** **Go** is decisively selected over Rust. While Rust offers marginally lower memory usage, the difference between 3MB and 7MB RAM on modern desktop Linux is negligible. In contrast, the Charm ecosystem (`bubbletea`, `lipgloss`, `bubbles`) enables rapid creation of gorgeous, production-grade terminal UIs with fractions of the boilerplate required by `ratatui`. Furthermore, pure-Go DBus eliminates runtime C library link errors across Linux distributions.
2. **Migration Timing:** Do **not** rewrite immediately in Go. Implement **v0.3.0 in Bash** first (regex ignore filters and burst deduplication). This locks down the exact user-facing configuration format, CLI flags, and filtering rules in rapid shell code. Once domain requirements are proven, execute the **Go core rewrite in v0.4.0**, followed by the **Bubble Tea TUI in v0.5.0** and the **v1.0.0 Production MVP**.

---

## Deferred Items Ledger

| ID | Type | Priority | Description | Containment / Reason | Target |
|---|---|---|---|---|---|
| DEF-001 | Feature | Medium | Custom regex ignore filter list for known harmless warnings | Planned for Bash stabilization milestone | 0.3.0 |
| DEF-002 | Feature | Low | Audio alert chime alongside notify-send | Optional user flag | 0.3.0 |
| DEF-003 | Feature | High | Rich Charm Bubble Tea interactive TUI log browser | Core planned deliverable for Go transition | 0.5.0 |
| DEF-004 | Architecture | Critical | Migrate core scanner from Bash to compiled Go binary | Resolves INV-06 complexity threshold | 0.4.0 |
| DEF-005 | Distribution | Medium | Multi-distro packaging (RPM spec, PKGBUILD, GoReleaser) | Part of Milestone 1 Production MVP | 1.0.0 |
| DEF-006 | Integration | Low | Remote webhook notification dispatch (ntfy.sh, Matrix) | Deferred to Milestone 2 | 2.0.0 |
