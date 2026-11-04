# AGENTS.md — warnify Project Rules & Invariants

> [!IMPORTANT]
> **PRIMARY LLM COORDINATION & HANDOFF LEDGER:**
> All autonomous agents operating in this repository must inspect and synchronize with the **Global Sync Ledger**:
> 👉 **[GitHub Issue #1: `[Handoff Ledger] [PRE-MVP] GLOBAL`](https://github.com/ktalanov/warnify/issues/1)** (labels: `sync-global`, `sync`).
> Active release receipts and evidence are posted to **[GitHub Issue #2 (v0.2.1)](https://github.com/ktalanov/warnify/issues/2)**.

> **Package:** `warnify` — Privileged journal warning monitor with desktop notifications and terminal log viewer.
> **Repository:** Local Git repository tracking GitHub upstream (`https://github.com/ktalanov/warnify`).
> **Symlink:** `~/.local/bin/,warnify.sh` -> `/home/lenin/github/warnify/warnify.sh`.
> **Current Version:** `v0.2.1`.

---

## Autonomous Agent Attribution Specification

All autonomous agents operating in this repository must format **every authored GitHub issue, pull request, handoff receipt, and comment** according to the following mandatory attribution standard:

1. **Header Prefix:**
   Every post must begin on the first line with the robot emoji and exact model identifier:
   ```markdown
   🤖 Antigravity (<Model> (<Effort>))
   ```
   *Rules:*
   - If the model name is unknown, do not guess; write `🤖 Antigravity (Unknown)`.
   - If effort is unknown or unconfigured, leave effort blank (e.g., `🤖 Antigravity (Gemini-3.8)`).
   - Example with known model and effort: `🤖 Antigravity (Gemini-3.8 (High))`.

2. **Footer Sign-off & Banter Quote:**
   Every post must conclude with a horizontal rule, model attribution, and a witty banter-style quote:
   ```markdown
   ---
   🤔 — Antigravity (<Model> (<Effort>))

   >"A humorous, banter-style quote related to this issue or commit" — me.
   ```

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
