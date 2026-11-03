# Roadmap — warnify

## Intended outcome

`warnify` is a privileged Linux system monitor that continuously tracks systemd journal logs for warnings, errors, and critical hardware/service failures (`journalctl -b -p 0..4`), dispatches non-blocking graphical desktop notifications to the active desktop session, and provides an interactive terminal log viewer with explicit PolicyKit elevation.

The ultimate target is a zero-configuration, robust, compiled daemon providing microsecond log evaluation, intelligent noise reduction, and a gorgeous Charm Bubble Tea terminal log inspector for developers, sysadmins, and Linux enthusiasts.

---

## Major-release outcomes and dependencies

## Milestone 1 — 0.1.0 → 1.0.0: Alpha Prototype to Production MVP

Transform the standalone Bash proof-of-concept into a production-grade, highly performant compiled daemon with rich interactive TUI inspection, flexible noise filtering, and distribution-ready packaging.

- **Outcome 1.1 (Foundational Prototype — v0.1.0..v0.2.1) [COMPLETED]:**
  - Standalone Bash automation inspecting `journalctl -b -p 0..4`.
  - Stateful cursor persistence (`/var/lib/warnify/cursor`) preventing duplicate notifications.
  - Active X11/Wayland desktop session discovery via DBus and `loginctl`.
  - Desktop notifications with penguin icon, origin tag (`[Kernel]`, `[systemd]`), and interactive `Open` action button.
  - Interactive terminal viewer spawning `xfce4-terminal -e pkexec journalctl ...`.
  - Startup boot-sweep mode and 2-minute incremental scans.
  - Triage hotfix (v0.2.1): POSIX `tr` syntax fix and single-pass streaming `jq -s` parser (reducing scan latency from 60+ min to 1.2s on 28k+ events; 24 automated tests passing).

- **Outcome 1.2 (Noise Reduction & Configuration Contract — v0.3.0) [TARGET]:**
  - Configurable regex ignore rules (`/etc/warnify/ignore.conf` and `~/.config/warnify/ignore.conf`) to suppress known harmless warnings (e.g. repetitive session scopes, transient Bluetooth disconnects).
  - Sliding-window warning burst deduplication and per-source alert cooldowns.
  - Optional subtle audio alert chime alongside desktop notifications.
  - Fully validate user-facing CLI flags and configuration syntax in Bash before committing to a compiled codebase.

- **Outcome 1.3 (Go Core Transition & Daemonization — v0.4.0) [TARGET]:**
  - Migrate execution core from Bash/subprocess scripts to a compiled **Go** binary (`warnify`).
  - Native C-level systemd journal access via `github.com/coreos/go-systemd/v22/sdjournal` (eliminating `journalctl` process spawning and memory overhead).
  - Native pure-Go DBus client (`github.com/godbus/dbus/v5`) for direct Freedesktop notification delivery without `notify-send`.
  - Microsecond scan execution (<10ms) and minimal memory footprint (<8MB RAM).
  - Native systemd watchdog (`sd_notify`) integration for reliable background operation.

- **Outcome 1.4 (Interactive Bubble Tea Terminal Inspector — v0.5.0) [TARGET]:**
  - Replace raw `pkexec journalctl` terminal launcher with a dedicated, aesthetic TUI browser built with `charmbracelet/bubbletea` and `charmbracelet/lipgloss`.
  - Interactive event log browser with live fuzzy search, origin filtering (Kernel, Services, Daemons), full stack-trace viewing, and export capabilities.
  - In-terminal PolicyKit authorization handling.

- **Outcome 1.5 (Production MVP Hardening & Packaging — v1.0.0) [TARGET]:**
  - Multi-seat and multi-user desktop session detection (broadcasting alerts across multiple active graphical displays).
  - Distribution packaging: RPM spec file (for Fedora/RHEL/CentOS), Arch PKGBUILD, and standalone static binary releases.
  - Automated CI matrix testing across Ubuntu, Fedora, and Arch with simulated systemd journals.
  - Complete documentation and manual pages (`man 1 warnify`).

---

## Milestone 2 — 1.0.0 → 2.0.0: Enterprise & Multi-Node Observability

Expand `warnify` from a single-workstation desktop monitor into an extensible observability sensor for multi-node clusters and headless servers.

- **Outcome 2.1 (Remote Notification Bridges):**
  - Built-in notification sinks for headless/remote servers: webhook dispatchers for `ntfy.sh`, Matrix, Slack, and Telegram.
  - Secure TLS token storage and per-channel severity routing.

- **Outcome 2.2 (Kernel eBPF Tracepoint Tap):**
  - Optional eBPF hardware error tap for sub-millisecond detection of kernel MCEs, thermal throttling, disk I/O timeouts, and OOM killer events before they hit disk journal files.

- **Outcome 2.3 (Multi-Node Cluster Aggregation):**
  - Peer-to-peer or central relay mode allowing a sysadmin desktop to aggregate warnings from multiple home-lab or production nodes into a single unified desktop feed.

---

## Decisions

### DEC-001: Language Selection — Go vs. Rust for `warnify`
- **Context:** `warnify.sh` exceeded the 500-line Bash maintainability ceiling (INV-06) and encountered shell process-forking bottlenecks on large journals. A compiled rewrite is planned.
- **Evaluation:**
  - **Rust:** Excellent memory safety, zero-cost abstractions, direct FFI to `libsystemd`. However, `ratatui` requires extensive state boilerplate for rich TUIs, async DBus (`zbus`) adds runtime complexity, and slow compile times impair rapid iteration.
  - **Go:** Outstanding ecosystem for interactive terminal tools via `charmbracelet/bubbletea`, `charmbracelet/lipgloss`, and `charmbracelet/bubbles` (directly realizing DEF-003). Pure-Go DBus client (`godbus/dbus`) eliminates libdbus C dependencies. Mature systemd integration (`coreos/go-systemd`). Microsecond execution and fast 1-2s compile cycles. Memory footprint (~8MB) is negligible on target desktop systems.
- **Decision:** **Adopt Go** as the migration language. The combination of Bubble Tea TUI power, pure-Go DBus, and fast developer velocity makes Go vastly superior for this product's goals.

### DEC-002: Staged Migration Timing (Bash v0.3.0 &rarr; Go v0.4.0)
- **Context:** Deciding whether to rewrite immediately in Go or add filtering features first.
- **Decision:** Implement **v0.3.0 in Bash** first (regex ignore lists and cooldown logic) to lock down the exact configuration syntax, filter behavior, and user experience in rapid shell script. Perform the **Go core rewrite in v0.4.0** once the domain requirements are 100% frozen.

