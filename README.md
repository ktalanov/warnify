# warnify

**Privileged journal warning monitor with desktop notifications and interactive terminal log viewer.**

`warnify` continuously monitors system logs (`journalctl`) for warnings, errors, and critical events with elevated privileges, sends rich desktop notifications into active graphical desktop sessions with an action button, and allows the user to inspect the underlying logs in `xfce4-terminal` using `pkexec` for authenticated access.

---

## Features

- **Comprehensive Journal Coverage:** Inspects all boot log messages of level `warning` or higher (`journalctl -b -p 0..4`), capturing kernel dmesg (`_TRANSPORT=kernel`), system services, and userspace daemons.
- **Stateful Cursor Tracking:** Employs `journalctl --cursor-file` to record the last-inspected log position, ensuring zero redundant or re-fired notifications across intervals.
- **Desktop Session Notification:** Dispatches critical notifications (`notify-send -u critical`) to the active graphical session, complete with a penguin icon, formatted event timestamps, and log source categorization.
- **Notification Flood Protection:** Batches bursts occurring in the same 1-minute window into a concise summary notification.
- **PolicyKit Privilege Elevation:** Provides an interactive `Open` button on notifications that spawns `xfce4-terminal -e pkexec journalctl ...`, ensuring explicit authorization via PolicyKit when viewing privileged log details.
- **Automation Ready:** Ships with systemd service and timer unit generators (`warnify.service`, `warnify.timer`) running every minute (`OnCalendar=*:0/1`).

---

## Prerequisites & Dependencies

- **Linux OS:** Fedora Linux (or modern systemd distribution)
- **Core Utilities:** `systemd` (`journalctl`), `bash` (4.4+), `jq`, `coreutils`
- **Desktop Environment:** Xfce4 / X11 / Wayland with a running notification daemon (`xfce4-notifyd` or Freedesktop-compliant daemon)
- **GUI Utilities:** `notify-send` (libnotify 0.8+ with action button support), `xfce4-terminal`, `pkexec` (polkit)

---

## Installation & Setup

### 1. Local User Symlink
```bash
ln -sf /home/lenin/github/warnify/warnify.sh ~/.local/bin/,warnify.sh
chmod +x ~/.local/bin/,warnify.sh
```

### 2. Install Systemd Timer (1-minute periodic monitor)
```bash
# Generate and install systemd unit and timer (requires elevation)
sudo /home/lenin/github/warnify/warnify.sh --install-systemd
```

To verify the timer:
```bash
systemctl list-timers warnify.timer
systemctl status warnify.timer
```

---

## Usage

```bash
warnify [options]

Options:
  -h, --help               Show this help message and exit
  -v, --version            Display version information (v0.1.0)
  -o, --once               Run a single check and exit immediately
  -d, --dry-run            Scan logs and print matching events to stdout without sending notifications
  -c, --cursor-file <path> Custom path to journal cursor state file (default: /var/lib/warnify/cursor)
  --priority <0..4>        Minimum severity filter (default: 0..4, warning or higher)
  --install-systemd        Install and enable systemd oneshot service and 1-minute timer
  --status                 Display current service, timer, and cursor status
```

---

## Project Documents

- [AGENTS.md](AGENTS.md) — Package-specific working rules and invariants
- [PLAN.md](PLAN.md) — Milestones, version roadmap, and verified tasks
- [ROADMAP.md](ROADMAP.md) — Major-release outcomes and dependencies
- [CHANGELOG.md](CHANGELOG.md) — Verified change history
- [HANDOFF.md](HANDOFF.md) — Unfinished work and state transitions
- [VERSION_GUIDE.md](VERSION_GUIDE.md) — Canonical SemVer guide
- [GUM_README.md](GUM_README.md) — Charm Gum reference
- [ISSUES.md](ISSUES.md) — Defect and enhancement ledger
