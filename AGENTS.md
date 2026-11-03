# AGENTS.md — warnify Project Rules & Invariants

> **Package:** `warnify` — Privileged journal warning monitor with desktop notifications and terminal log viewer.
> **Repository:** Local Git repository tracking GitHub upstream (`https://github.com/ktalanov/warnify`).
> **Symlink:** `~/.local/bin/,warnify.sh` -> `/home/lenin/github/warnify/warnify.sh`.
> **Current Version:** `v0.2.1`.
> **Global Handoff Ledger:** [Issue #1 (`sync-global`, `sync`)](https://github.com/ktalanov/warnify/issues/1).
> **Version Handoff Ledger:** [Issue #2 (`sync`)](https://github.com/ktalanov/warnify/issues/2).

---

## Purpose & Architecture

`warnify` is an automated system monitor that detects warnings, errors, and critical system events from `journalctl`, dispatches desktop notifications to the active desktop session, and provides a one-click action to view the error in an authenticated terminal log viewer.

### Core Architecture & Boundaries
1. **Log Inspection Engine:**
   - Runs with root privileges to inspect `journalctl -b -p 0..4` (emergencies, alerts, criticals, errors, warnings).
   - Tracks processed records statefully via `--cursor-file=/var/lib/warnify/cursor` and boot ID via `/var/lib/warnify/boot_id` to prevent duplicate alerts.
   - Categorizes event origin: kernel (`_TRANSPORT=kernel` / dmesg), system services (`_SYSTEMD_UNIT`), or user/system daemons (`SYSLOG_IDENTIFIER` / `_COMM`).
   - Parses logs via a single-pass streaming `jq -s` pipeline, capping historical boot sweep scans to `-n 1000` to prevent memory bloat and process-fork overhead.
2. **Notification Dispatcher:**
   - Drops privilege or targets the active graphical user session via DBus (`DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus"`).
   - Sends desktop notifications via `notify-send` with critical urgency (`-u critical`), penguin/tux icon, timestamp, origin tag, top-5 category summary, and an `Open` action button (`-A open=Open`).
   - Batches bursts occurring in the same 2-minute sampling window into a clean summary notification to avoid desktop notification flooding.
3. **Privileged Terminal Viewer:**
   - When the user clicks `Open`, the handler spawns `xfce4-terminal -e "pkexec journalctl ..."` focused on the relevant cursor or time window.
   - Future v0.5.0 milestone replaces the pager with a native Charm Bubble Tea TUI browser.
4. **Automation / Timer:**
   - Systemd units: `/etc/systemd/system/warnify.service` (oneshot) and `/etc/systemd/system/warnify.timer` (`OnBootSec=1min`, `OnUnitActiveSec=2min`).

---

## Directory & File Invariants

- **INV-07 (Directory Preservation Invariant):** All repository directories documented in `README.md` (`assets/`, `systemd/`, `reports/`, `tmp/`) must **never** be placed in `.gitignore`. They must remain tracked or preserved in the workspace.
- `tmp/` is dedicated for holding scratch, exploratory, or temporary files.

---

## Project-Specific Commands

```bash
# Syntax and static checks
bash -n warnify.sh
bash -n test_warnify.sh

# Run test suite (executable, 24 automated tests passing)
./test_warnify.sh

# Check version
cat VERSION.md

# Inspect status and boot detection
./warnify.sh --status

# Manual dry-run check (non-root safe mode)
./warnify.sh --dry-run
```

---

## Language Evolution & Migration Policy

- **Current State:** Bash utility (`warnify.sh`, ~620 lines) optimized with streaming `jq -s`.
- **v0.3.0 Stabilization:** Implement regex ignore filters (`ignore.conf`) and burst cooldown in Bash to lock down user requirements.
- **v0.4.0 Go Transition:** Migrate core scanner to a compiled **Go** application (`coreos/go-systemd/v22/sdjournal` and `godbus/dbus/v5`) per `INV-06`. Go is chosen over Rust due to the rich Charm Bubble Tea TUI ecosystem, pure-Go DBus, and fast iteration cycles.
- **v0.5.0 TUI Viewer:** Embed `charmbracelet/bubbletea` interactive log viewer into `warnify view`.

---

## Completion Evidence & Release Gates

- All companion files must remain synchronized with `VERSION.md` (`v0.2.1`).
- Automated tests (`./test_warnify.sh`, 24 tests) must pass 100% without errors.
- CLI flags (`--help`, `--version`, `--dry-run`, `--once`, `--boot-sweep`, `--cursor-file`, `--status`, `--install-systemd`) and systemd unit generation must be covered by tests.
- Updates must be recorded in `CHANGELOG.md` following Keep a Changelog format.
