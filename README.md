# warnify

**Privileged journal warning monitor with desktop notifications, startup boot-sweep, and interactive terminal log viewer.**

`warnify` continuously monitors system logs (`journalctl`) for warnings, errors, and critical events with elevated privileges, sends rich desktop notifications into active graphical desktop sessions with an action button, and allows the user to inspect the underlying logs in `xfce4-terminal` using `pkexec` for authenticated access.

---

## Features

- **Startup Boot-Sweep:** On initial boot or when uptime is under 2 minutes, `warnify` performs a comprehensive sweep of **all** warning/error events from system startup to current time across all logs (`journalctl -b -p 0..4`), capturing kernel dmesg, system services, and userspace daemons.
- **Windowed 2-Minute Incremental Scans:** For routine periodic checks, `warnify` restricts its scan to the last 2 minutes + buffer (`--since="3 minutes ago"`) combined with `--after-cursor` tracking, ensuring it never rescans the full historical journal over and over.
- **Stateful Cursor & Boot Tracking:** Records cursor and boot ID state (`/var/lib/warnify/cursor`, `/var/lib/warnify/boot_id`) to automatically detect system reboots and prevent duplicate notifications.
- **Desktop Session Notification:** Dispatches critical notifications (`notify-send -u critical`) to the active graphical session, complete with a penguin icon, formatted event timestamps, and log source categorization (`[Kernel (dmesg)]`, `[bluetooth.service]`, etc.).
- **Notification Flood Protection:** Batches bursts occurring in the same check window into a concise summary notification.
- **PolicyKit Privilege Elevation:** Provides an interactive `Open` button on notifications that spawns `xfce4-terminal -e pkexec journalctl ...`, ensuring explicit authorization via PolicyKit when viewing privileged log details.
- **Flexible Execution Modes:** Runs either via systemd timer (`warnify.timer` triggered 1 min after boot, then every 2 minutes), via cron, or as a standalone foreground daemon (`warnify --daemon`).

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

### 2. Install Systemd Timer (Startup trigger + 2-minute periodic monitor)
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
  -v, --version            Display version information (v0.2.0)
  -o, --once               Run a single log scan cycle and exit (default)
  -D, --daemon             Run continuously as a foreground daemon (scans every 2 minutes)
  -d, --dry-run            Scan logs and print matching events to stdout without notifying or advancing cursor
  -b, --boot-sweep         Force a full boot sweep of all warnings since system boot
  -c, --cursor-file <FILE> Path to cursor state file (default: /var/lib/warnify/cursor)
      --state-dir <DIR>    Directory for cursor and boot state (default: /var/lib/warnify)
      --priority <LEVEL>   Journalctl priority range (default: 0..4, warning or higher)
      --status             Show systemd timer, service, uptime, and cursor status
      --install-systemd    Install and activate systemd service and 2-minute timer (requires root/sudo)
      --uninstall-systemd  Stop, disable, and remove systemd service and timer (requires root/sudo)
      --print-systemd-units Print systemd service and timer unit definitions
      --view <CURSOR>      Launch privileged journal log viewer focused on cursor

Examples:
  warnify --dry-run
  warnify --boot-sweep --dry-run
  warnify --daemon
  sudo warnify --install-systemd
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
