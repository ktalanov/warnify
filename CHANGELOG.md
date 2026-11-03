# Changelog — warnify

All notable verified changes to this project will be recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-11-03

### Fixed

- Boot ID detection syntax error: Replaced invalid `tr -d '-\n\r '` with POSIX-compliant `tr -d '[:space:]-'`, ensuring `/proc/sys/kernel/random/boot_id` is cleanly parsed instead of falling back to `"unknown"`.
- Eliminated O(N) process fork bomb in `scan_journal`: Replaced the Bash `for` loop calling `jq` 7 times per event with a unified streaming `jq -s` pipeline, reducing execution time on large journals (28k+ events) from >60 minutes to <1.5 seconds.
- Bounded boot sweep inspection: Capped historical boot-sweep scan to `-n 1000` to prevent memory bloat on workstations with weeks of accumulated journal entries.
- Category summary aggregation: Summarized top-5 warning categories in notification bodies to prevent DBus/notify-send buffer overflows from repetitive session scope messages.
- Test runner deadlock: Fixed `test_warnify.sh` hanging indefinitely on Test 6 and added assertion verifying `boot_id` resolves to a valid UUID (expanding suite to 24 tests).


## [0.2.0] - 2026-10-24

### Added

- Startup boot-sweep mode: Automatically detects system reboots and uptime under 2 minutes, scanning all warning/error logs from startup to now (`journalctl -b -p 0..4`).
- Bounded 2-minute incremental scan window (`--since="3 minutes ago"`) combined with `--after-cursor` state tracking to prevent scanning the full historical journal repeatedly.
- System boot ID tracking via `/proc/sys/kernel/random/boot_id` stored in `state-dir/boot_id` for reliable reboot detection.
- Updated systemd timer configuration with `OnBootSec=1min` (startup trigger) and `OnUnitActiveSec=2min` (2-minute periodic interval).
- Added `-D, --daemon` mode flag to run as a continuous foreground loop with 120s sleep intervals.
- Added `-b, --boot-sweep` flag to manually force a full boot warning sweep.
- Expanded automated test suite in `test_warnify.sh` to 23 tests, covering boot detection, boot sweep mode, and updated systemd intervals.

## [0.1.0] - 2026-10-24

### Added

- `warnify.sh`: Core Bash automation script monitoring `journalctl -b -p 0..4` (emergency to warning).
- Stateful cursor persistence via `--cursor-file` (defaults to `/var/lib/warnify/cursor` or user cache).
- Active desktop session detection via `loginctl` inspecting `x11` and `wayland` graphical sessions.
- Desktop notifications (`notify-send -u critical`) with penguin icon (`assets/penguin.png`) and `-A open="Open Log"` button.
- Notification burst batching to summarize multiple warnings occurring in the same interval.
- Interactive viewer launcher in `xfce4-terminal` invoking `pkexec journalctl --cursor=... -n 50 -xb` on action click.
- Systemd automation templates: `systemd/warnify.service` and `systemd/warnify.timer`.
- CLI commands: `--dry-run`, `--once`, `--cursor-file`, `--priority`, `--status`, `--install-systemd`, `--uninstall-systemd`, and `--print-systemd-units`.
- Automated test suite `test_warnify.sh`.
- Local user symlink at `~/.local/bin/,warnify.sh`.
