#!/usr/bin/env bash
# warnify.sh — Privileged journal warning monitor with desktop notifications and terminal log viewer
# Author: Kirill Talanov <code@talanov.ca>
# License: MIT
set -euo pipefail

VERSION="0.2.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_FILE="${SCRIPT_DIR}/assets/penguin.png"

# Defaults
DEFAULT_PRIORITY="0..4" # emerg, alert, crit, err, warning
if [[ $(id -u) -eq 0 ]]; then
  DEFAULT_STATE_DIR="/var/lib/warnify"
else
  DEFAULT_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/warnify"
fi

STATE_DIR="${DEFAULT_STATE_DIR}"
CURSOR_FILE="${STATE_DIR}/cursor"
BOOT_FILE="${STATE_DIR}/boot_id"
PRIORITY="${DEFAULT_PRIORITY}"
DRY_RUN=false
ONCE_MODE=true
DAEMON_MODE=false
FORCE_BOOT_SWEEP=false
INTERVAL_SECS=120
SCAN_WINDOW="3 minutes ago" # 2 minutes cadence + 1 minute buffer

# Helper: Print usage
usage() {
  cat <<EOF
Usage: warnify [options]

Privileged journal warning monitor with desktop notifications and terminal log viewer.

Options:
  -h, --help               Show this help message and exit
  -v, --version            Display version information (v${VERSION})
  -o, --once               Run a single log scan cycle and exit (default)
  -D, --daemon             Run continuously as a foreground daemon (scans every 2 minutes)
  -d, --dry-run            Scan logs and print matching events to stdout without notifying or advancing cursor
  -b, --boot-sweep         Force a full boot sweep of all warnings since system boot
  -c, --cursor-file <FILE> Path to cursor state file (default: ${CURSOR_FILE})
      --state-dir <DIR>    Directory for cursor and boot state (default: ${STATE_DIR})
      --priority <LEVEL>   Journalctl priority range (default: ${DEFAULT_PRIORITY})
      --status             Show systemd timer, service, and cursor status
      --install-systemd    Install and activate systemd service and 2-minute timer (requires root/sudo)
      --uninstall-systemd  Stop, disable, and remove systemd service and timer (requires root/sudo)
      --print-systemd-units Print systemd service and timer unit definitions
      --view <CURSOR>      Launch privileged journal log viewer focused on cursor

Examples:
  warnify --dry-run
  warnify --boot-sweep --dry-run
  sudo warnify --install-systemd
EOF
}

# Helper: Print version
version() {
  echo "warnify v${VERSION}"
}

# Helper: Ensure dependencies exist
check_deps() {
  local missing=()
  for cmd in journalctl jq notify-send xfce4-terminal pkexec; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Warning: missing recommended tools: ${missing[*]}" >&2
  fi
}

# Helper: Get system uptime in seconds
get_uptime_seconds() {
  if [[ -f /proc/uptime ]]; then
    awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 9999
  else
    echo 9999
  fi
}

# Helper: Get system boot ID
get_current_boot_id() {
  if [[ -f /proc/sys/kernel/random/boot_id ]]; then
    tr -d '[:space:]-' < /proc/sys/kernel/random/boot_id 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

# Helper: Determine if this run should be a full boot-sweep
is_boot_sweep_needed() {
  if [[ "${FORCE_BOOT_SWEEP}" == "true" ]]; then
    return 0
  fi

  local uptime_sec
  uptime_sec=$(get_uptime_seconds)
  if [[ "${uptime_sec}" -lt 120 ]]; then
    return 0
  fi

  local current_boot
  current_boot=$(get_current_boot_id)
  if [[ ! -f "${BOOT_FILE}" ]]; then
    return 0
  fi

  local recorded_boot
  recorded_boot=$(tr -d '[:space:]-' < "${BOOT_FILE}" 2>/dev/null || echo "")
  if [[ -z "${recorded_boot}" || "${recorded_boot}" != "${current_boot}" ]]; then
    return 0
  fi

  return 1
}

# Helper: Classify event source from raw JSON object
classify_event() {
  local json_line="$1"
  echo "${json_line}" | jq -r '
    if ._TRANSPORT == "kernel" then "Kernel (dmesg)"
    elif (._SYSTEMD_UNIT // "") != "" then ._SYSTEMD_UNIT
    elif (.SYSLOG_IDENTIFIER // "") != "" then .SYSLOG_IDENTIFIER
    elif (._COMM // "") != "" then ._COMM
    else "system" end'
}

# Helper: Convert journal realtime timestamp (microseconds) to human-readable string
format_timestamp() {
  local usec="$1"
  if [[ -z "${usec}" || "${usec}" == "null" ]]; then
    date "+%Y-%m-%d %H:%M:%S"
    return
  fi
  local sec=$((usec / 1000000))
  date -d "@${sec}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date "+%Y-%m-%d %H:%M:%S"
}

# Helper: Detect active graphical desktop session and user
detect_active_session() {
  # If user already has DBUS and DISPLAY set, use them directly
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && -n "${DISPLAY:-}" ]]; then
    echo "$(id -u):$(id -un):${DISPLAY}:${DBUS_SESSION_BUS_ADDRESS}"
    return
  fi

  # Otherwise inspect loginctl sessions (running as root or daemon)
  if command -v loginctl >/dev/null 2>&1; then
    while read -r session uid user seat; do
      if [[ -n "${session}" && "${session}" != "SESSION" ]]; then
        local stype sdisp
        stype=$(loginctl show-session "${session}" -p Type --value 2>/dev/null || true)
        sdisp=$(loginctl show-session "${session}" -p Display --value 2>/dev/null || true)
        if [[ "${stype}" == "x11" || "${stype}" == "wayland" ]]; then
          local dbus="unix:path=/run/user/${uid}/bus"
          [[ -z "${sdisp}" ]] && sdisp=":0"
          echo "${uid}:${user}:${sdisp}:${dbus}"
          return
        fi
      fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null || true)
  fi

  # Fallback to current user or UID 1000
  local fallback_uid="${SUDO_UID:-1000}"
  local fallback_user
  fallback_user=$(id -nu "${fallback_uid}" 2>/dev/null || echo "lenin")
  echo "${fallback_uid}:${fallback_user}::0:unix:path=/run/user/${fallback_uid}/bus"
}

# Helper: Launch viewer in terminal
launch_viewer() {
  local cursor="$1"
  local target_user="$2"
  local target_disp="$3"

  local view_cmd=""
  if [[ -n "${cursor}" ]]; then
    view_cmd="pkexec journalctl --cursor=\"${cursor}\" -n 50 -xb; echo; read -n 1 -s -r -p 'Press any key to close...'"
  else
    view_cmd="pkexec journalctl -b -p 0..4; echo; read -n 1 -s -r -p 'Press any key to close...'"
  fi

  if [[ $(id -u) -eq 0 && -n "${target_user}" && "${target_user}" != "root" ]]; then
    su - "${target_user}" -c "DISPLAY='${target_disp}' xfce4-terminal --title='warnify: System Warning Details' -e \"bash -c '${view_cmd}'\"" >/dev/null 2>&1 &
  else
    DISPLAY="${target_disp}" xfce4-terminal --title="warnify: System Warning Details" -e "bash -c '${view_cmd}'" >/dev/null 2>&1 &
  fi
}

# Helper: Send desktop notification
send_notification() {
  local title="$1"
  local body="$2"
  local cursor="$3"

  local session_info
  session_info=$(detect_active_session)
  local target_uid target_user target_disp target_dbus
  IFS=':' read -r target_uid target_user target_disp target_dbus <<< "${session_info}"

  local icon_arg=()
  if [[ -f "${ICON_FILE}" ]]; then
    icon_arg=("-i" "${ICON_FILE}")
  else
    icon_arg=("-i" "dialog-warning")
  fi

  # Run notify-send in the target desktop session
  local action=""
  if [[ $(id -u) -eq 0 && "${target_user}" != "root" ]]; then
    action=$(sudo -u "${target_user}" \
      DBUS_SESSION_BUS_ADDRESS="${target_dbus}" \
      DISPLAY="${target_disp}" \
      notify-send -u critical \
        "${icon_arg[@]}" \
        -A "open=Open Log" \
        "${title}" \
        "${body}" 2>/dev/null || true)
  else
    action=$(DBUS_SESSION_BUS_ADDRESS="${target_dbus}" \
      DISPLAY="${target_disp}" \
      notify-send -u critical \
        "${icon_arg[@]}" \
        -A "open=Open Log" \
        "${title}" \
        "${body}" 2>/dev/null || true)
  fi

  if [[ "${action}" == "open" || "${action}" == "0" ]]; then
    launch_viewer "${cursor}" "${target_user}" "${target_disp}"
  fi
}

# Core: Process log query
scan_journal() {
  local is_boot_sweep=false
  if is_boot_sweep_needed; then
    is_boot_sweep=true
  fi

  local journal_args=("-b" "-p" "${PRIORITY}" "-o" "json")

  if [[ "${is_boot_sweep}" == "true" ]]; then
    # Full boot sweep: inspect boot warnings (capped to 1000 to avoid runaway memory)
    journal_args+=("-n" "1000")
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "[warnify] (dry-run) Mode: Full boot-sweep (scanning entire boot log from startup)"
    fi
  else
    # Routine 2-minute incremental scan: restrict to window + cursor
    journal_args+=("--since=${SCAN_WINDOW}")
    if [[ -f "${CURSOR_FILE}" && -s "${CURSOR_FILE}" ]]; then
      local saved_cursor
      saved_cursor=$(tr -d '[:space:]' < "${CURSOR_FILE}")
      if [[ -n "${saved_cursor}" ]]; then
        journal_args+=("--after-cursor=${saved_cursor}")
      fi
    fi
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "[warnify] (dry-run) Mode: 2-minute incremental window (--since=${SCAN_WINDOW})"
    fi
  fi

  local parsed_json
  parsed_json=$(journalctl "${journal_args[@]}" 2>/dev/null | jq -s '
    def classify:
      if ._TRANSPORT == "kernel" then "Kernel (dmesg)"
      elif (._SYSTEMD_UNIT // "") != "" then ._SYSTEMD_UNIT
      elif (.SYSLOG_IDENTIFIER // "") != "" then .SYSLOG_IDENTIFIER
      elif (._COMM // "") != "" then ._COMM
      else "system" end;

    if length == 0 then
      {count: 0}
    else
      {
        count: length,
        first_cursor: .[0].__CURSOR,
        last_cursor: .[-1].__CURSOR,
        last_source: (.[-1] | classify),
        last_time: .[-1].__REALTIME_TIMESTAMP,
        last_msg: ((.[-1].MESSAGE // "") | gsub("[\r\n\t]"; " ") | .[0:140]),
        summary: (
          reduce .[] as $item ({}; .[$item | classify] = (.[$item | classify] // 0) + 1)
          | to_entries
          | sort_by(-.value)
          | .[:5]
          | map("\(.key): \(.value)")
          | join(", ")
        ),
        events_sample: (
          if length <= 50 then
            map({
              cursor: (.__CURSOR // ""),
              source: classify,
              time: (.__REALTIME_TIMESTAMP // ""),
              msg: ((.MESSAGE // "") | gsub("[\r\n\t]"; " ") | .[0:80])
            })
          else
            (.[-50:] | map({
              cursor: (.__CURSOR // ""),
              source: classify,
              time: (.__REALTIME_TIMESTAMP // ""),
              msg: ((.MESSAGE // "") | gsub("[\r\n\t]"; " ") | .[0:80])
            }))
          end
        )
      }
    end
  ' 2>/dev/null || echo '{"count": 0}')

  local count
  count=$(echo "${parsed_json}" | jq -r '.count // 0')

  if [[ "${count}" -eq 0 ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "[warnify] No new warnings or errors detected."
    fi
    # If this was a successful boot sweep, record the boot ID so we switch to incremental
    if [[ "${is_boot_sweep}" == "true" && "${DRY_RUN}" != "true" ]]; then
      mkdir -p "$(dirname "${BOOT_FILE}")"
      get_current_boot_id > "${BOOT_FILE}"
    fi
    return 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[warnify] Detected ${count} warning/error event(s):"
  fi

  local first_cursor last_cursor last_source last_time_usec summary
  first_cursor=$(echo "${parsed_json}" | jq -r '.first_cursor // empty')
  last_cursor=$(echo "${parsed_json}" | jq -r '.last_cursor // empty')
  last_source=$(echo "${parsed_json}" | jq -r '.last_source // "system"')
  last_time_usec=$(echo "${parsed_json}" | jq -r '.last_time // empty')
  summary=$(echo "${parsed_json}" | jq -r '.summary // ""')
  local last_msg
  last_msg=$(echo "${parsed_json}" | jq -r '.last_msg // ""')
  local last_time
  last_time=$(format_timestamp "${last_time_usec}")

  if [[ "${DRY_RUN}" == "true" ]]; then
    while IFS=$'\t' read -r s_cur s_source s_time s_msg; do
      if [[ -n "${s_source}" ]]; then
        local formatted_time
        formatted_time=$(format_timestamp "${s_time}")
        echo "  • [${formatted_time}] [${s_source}] ${s_msg}"
      fi
    done < <(echo "${parsed_json}" | jq -r '.events_sample[]? | [.cursor, .source, .time, .msg] | @tsv')
  fi

  # Build notification
  if [[ "${DRY_RUN}" != "true" ]]; then
    local title=""
    local body=""

    if [[ "${is_boot_sweep}" == "true" ]]; then
      title="⚠️ Boot Warnings: ${count} Events Detected"
      body="Boot sweep analyzed warnings from startup to now.\nBreakdown: ${summary}\nLatest: ${last_msg:0:100}"
    elif [[ "${count}" -eq 1 ]]; then
      title="⚠️ System Warning: [${last_source}]"
      body="Time: ${last_time}\nSource: ${last_source}\n\n${last_msg:0:140}"
    else
      # Summarize categories for 2-minute cycle
      title="⚠️ ${count} New Warnings in Last 2 Minutes"
      body="Time: ${last_time}\nBreakdown: ${summary}\nLatest: ${last_msg:0:100}"
    fi

    # Dispatch notification asynchronously
    send_notification "${title}" "${body}" "${first_cursor}" &

    # Update cursor state and record boot ID
    mkdir -p "$(dirname "${CURSOR_FILE}")"
    if [[ -n "${last_cursor}" ]]; then
      echo "${last_cursor}" > "${CURSOR_FILE}"
    fi
    mkdir -p "$(dirname "${BOOT_FILE}")"
    get_current_boot_id > "${BOOT_FILE}"
  fi
}

# Helper: Print systemd units
print_systemd_units() {
  cat <<'EOF'
=== /etc/systemd/system/warnify.service ===
[Unit]
Description=warnify - Privileged journal warning monitor
After=network.target

[Service]
Type=oneshot
ExecStart=/home/lenin/github/warnify/warnify.sh --once
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target

=== /etc/systemd/system/warnify.timer ===
[Unit]
Description=warnify - Run journal warning monitor every 2 minutes (with startup trigger)
After=network.target

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
AccuracySec=5s
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

# Helper: Install systemd units
install_systemd() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "Error: --install-systemd requires root privileges (run with sudo or pkexec)." >&2
    exit 1
  fi

  local service_file="/etc/systemd/system/warnify.service"
  local timer_file="/etc/systemd/system/warnify.timer"
  local script_path="${SCRIPT_DIR}/warnify.sh"

  cat > "${service_file}" <<EOF
[Unit]
Description=warnify - Privileged journal warning monitor
After=network.target

[Service]
Type=oneshot
ExecStart=${script_path} --once
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  cat > "${timer_file}" <<EOF
[Unit]
Description=warnify - Run journal warning monitor every 2 minutes (with startup trigger)
After=network.target

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
AccuracySec=5s
Persistent=true

[Install]
WantedBy=timers.target
EOF

  mkdir -p /var/lib/warnify
  chmod 644 "${service_file}" "${timer_file}"
  systemctl daemon-reload
  systemctl enable --now warnify.timer
  echo "Successfully installed and enabled warnify.timer (running 1 min after boot, then every 2 minutes)."
  systemctl list-timers warnify.timer --no-pager
}

# Helper: Uninstall systemd units
uninstall_systemd() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "Error: --uninstall-systemd requires root privileges (run with sudo or pkexec)." >&2
    exit 1
  fi

  systemctl stop warnify.timer 2>/dev/null || true
  systemctl disable warnify.timer 2>/dev/null || true
  rm -f /etc/systemd/system/warnify.service /etc/systemd/system/warnify.timer
  systemctl daemon-reload
  echo "Successfully stopped and removed warnify systemd units."
}

# Helper: Check status
show_status() {
  echo "=== warnify Status ==="
  echo "Version: ${VERSION}"
  echo "Script path: ${SCRIPT_DIR}/warnify.sh"
  echo "Uptime: $(get_uptime_seconds)s"
  echo "Current boot ID: $(get_current_boot_id)"
  echo "State directory: ${STATE_DIR}"
  if [[ -f "${BOOT_FILE}" ]]; then
    echo "Recorded boot ID: $(cat "${BOOT_FILE}")"
  else
    echo "Recorded boot ID: None (will trigger boot-sweep on next run)"
  fi
  if [[ -f "${CURSOR_FILE}" ]]; then
    echo "Cursor state: $(cat "${CURSOR_FILE}")"
  else
    echo "Cursor state: Not initialized yet"
  fi
  echo ""
  echo "--- Systemd Timer Status ---"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status warnify.timer --no-pager 2>&1 || echo "warnify.timer is not active"
  fi
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      version
      exit 0
      ;;
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -b|--boot-sweep)
      FORCE_BOOT_SWEEP=true
      shift
      ;;
    -o|--once)
      ONCE_MODE=true
      shift
      ;;
    -D|--daemon)
      DAEMON_MODE=true
      shift
      ;;
    -c|--cursor-file)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --cursor-file requires a path argument." >&2
        exit 1
      fi
      CURSOR_FILE="$2"
      shift 2
      ;;
    --state-dir)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --state-dir requires a directory path." >&2
        exit 1
      fi
      STATE_DIR="$2"
      CURSOR_FILE="${STATE_DIR}/cursor"
      BOOT_FILE="${STATE_DIR}/boot_id"
      shift 2
      ;;
    --priority)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --priority requires a priority argument (e.g. 0..4)." >&2
        exit 1
      fi
      PRIORITY="$2"
      shift 2
      ;;
    --status)
      show_status
      exit 0
      ;;
    --print-systemd-units)
      print_systemd_units
      exit 0
      ;;
    --install-systemd)
      install_systemd
      exit 0
      ;;
    --uninstall-systemd)
      uninstall_systemd
      exit 0
      ;;
    --view)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --view requires a cursor string." >&2
        exit 1
      fi
      launch_viewer "$2" "$(id -un)" "${DISPLAY:-:0}"
      exit 0
      ;;
    --test-classify)
      while IFS= read -r line; do
        classify_event "$line"
      done
      exit 0
      ;;
    --test-process-events)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --test-process-events requires a cursor file." >&2
        exit 1
      fi
      test_cur_file="$2"
      while IFS= read -r line; do
        c=$(echo "$line" | jq -r '.__CURSOR // empty')
        if [[ -n "$c" ]]; then
          echo "$c" > "${test_cur_file}"
        fi
      done
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

check_deps

if [[ "${DAEMON_MODE}" == "true" ]]; then
  echo "[warnify] Starting foreground daemon loop (interval: ${INTERVAL_SECS}s)..."
  while true; do
    scan_journal
    sleep "${INTERVAL_SECS}"
  done
else
  scan_journal
fi
