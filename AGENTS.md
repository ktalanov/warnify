# AGENTS.md — warnify Project Rules & Invariants

> **Package:** `warnify` — Privileged journal warning monitor with desktop notifications and terminal log viewer.
> **Repository:** Standalone local Git repository (`/home/lenin/github/warnify`).
> **Symlink:** `~/.local/bin/,warnify.sh` -> `/home/lenin/github/warnify/warnify.sh`.

---

## Purpose & Architecture

`warnify` is an automated system monitor that detects warnings, errors, and critical system events from `journalctl`, dispatches desktop notifications to the active desktop session, and provides a one-click action to view the error in `xfce4-terminal` using `pkexec`.

### Core Architecture & Boundaries
1. **Log Inspection Engine:**
   - Runs with root privileges to inspect `journalctl -b -p 0..4` (emergencies, alerts, criticals, errors, warnings).
   - Tracks processed records statefully via `--cursor-file=/var/lib/warnify/cursor` to prevent duplicate alerts.
   - Categorizes event origin: kernel (`_TRANSPORT=kernel` / dmesg), system services (`_SYSTEMD_UNIT`), or user/system daemons (`SYSLOG_IDENTIFIER` / `_COMM`).
2. **Notification Dispatcher:**
   - Drops privilege or targets the active graphical user session via DBus (`DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${TARGET_UID}/bus"`).
   - Sends desktop notifications via `notify-send` with critical urgency (`-u critical`), penguin/tux icon, timestamp, origin tag, and an `Open` action button (`-A open=Open`).
   - Batches bursts occurring in the same 1-minute sampling window into a clean summary notification to avoid desktop notification flooding.
3. **Privileged Terminal Viewer:**
   - When the user clicks `Open`, the handler spawns `xfce4-terminal -e "pkexec journalctl ..."` focused on the relevant cursor or time window.
   - Using `pkexec` ensures the user is interactively prompted for elevation by PolicyKit when inspecting privileged logs.
4. **Automation / Timer:**
   - Systemd units: `/etc/systemd/system/warnify.service` (oneshot) and `/etc/systemd/system/warnify.timer` (`OnCalendar=*:0/1`, running every minute).

---

## Project-Specific Commands

```bash
# Syntax and static checks
bash -n warnify.sh
bash -n test_warnify.sh
shellcheck warnify.sh test_warnify.sh

# Run test suite (executable, non-interactive / mocked journal mode)
./test_warnify.sh

# Check version
cat VERSION.md

# Manual dry-run check (non-root safe mode)
./warnify.sh --dry-run
```

---

## Completion Evidence & Release Gates

- All companion files must remain synchronized with `VERSION.md` (`v0.1.0`).
- Automated tests (`./test_warnify.sh`) must pass 100% without errors.
- Both CLI flags (`--help`, `--version`, `--dry-run`, `--once`, `--cursor-file`) and systemd unit generation must be covered by tests.
- Updates must be recorded in `CHANGELOG.md` following Keep a Changelog format.
