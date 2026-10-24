# Changelog — warnify

All notable verified changes to this project will be recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-24

### Added

- `warnify.sh`: Core Bash automation script monitoring `journalctl -b -p 0..4` (emergency to warning).
- Stateful cursor persistence via `--cursor-file` (defaults to `/var/lib/warnify/cursor` or user cache).
- Active desktop session detection via `loginctl` inspecting `x11` and `wayland` graphical sessions.
- Desktop notifications (`notify-send -u critical`) with penguin icon (`assets/penguin.png`) and `-A open="Open Log"` button.
- Notification burst batching to summarize multiple warnings occurring in the same interval.
- Interactive viewer launcher in `xfce4-terminal` invoking `pkexec journalctl --cursor=... -n 50 -xb` on action click.
- Systemd automation templates: `systemd/warnify.service` and `systemd/warnify.timer` configured for 1-minute intervals (`OnCalendar=*:0/1`).
- CLI commands: `--dry-run`, `--once`, `--cursor-file`, `--priority`, `--status`, `--install-systemd`, `--uninstall-systemd`, and `--print-systemd-units`.
- Automated test suite `test_warnify.sh` with 16 automated tests covering syntax, arguments, parsing, cursor state, and unit definitions.
- Local user symlink at `~/.local/bin/,warnify.sh`.
