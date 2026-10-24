#!/usr/bin/env bash
# warnify.sh — Privileged journal warning monitor with desktop notifications and terminal log viewer
# Author: Kirill Talanov <code@talanov.ca>
# License: MIT
set -euo pipefail

VERSION="0.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_FILE="${SCRIPT_DIR}/assets/penguin.png"

# Defaults
DEFAULT_PRIORITY="0..4" # emerg, alert, crit, err, warning
if [[ $(id -u) -eq 0 ]]; then
  DEFAULT_CURSOR_FILE="/var/lib/warnify/cursor"
else
  DEFAULT_CURSOR_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/warnify/cursor"
fi

CURSOR_FILE="${DEFAULT_CURSOR_FILE}"
PRIORITY="${DEFAULT_PRIORITY}"
DRY_RUN=false
ONCE_MODE=true

# Helper: Print usage
usage() {
  cat <<EOF
Usage: warnify [options]

Privileged journal warning monitor with desktop notifications and terminal log viewer.

Options:
  -h, --help               Show this help message and exit
  -v, --version            Display version information (v${VERSION})
  -o, --once               Run a single log scan cycle and exit (default)
  -d, --dry-run            Scan logs and print matching events to stdout without notifying or advancing cursor
  -c, --cursor-file <FILE> Path to cursor state file (default: ${DEFAULT_CURSOR_FILE})
      --priority <LEVEL>   Journalctl priority range (default: ${DEFAULT_PRIORITY})
      --status             Show systemd timer, service, and cursor status
      --install-systemd    Install and activate systemd service and 1-minute timer (requires root/sudo)
      --uninstall-systemd  Stop, disable, and remove systemd service and timer (requires root/sudo)
      --print-systemd-units Print systemd service and timer unit definitions
      --view <CURSOR>      Launch privileged journal log viewer focused on cursor

Examples:
  warnify --dry-run
  warnify --cursor-file /tmp/mycursor
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

# Helper: Classify event source from raw JSON object
classify_event() {
  local json_line="$1"
  local transport unit syslog_id comm
  transport=$(echo "${json_line}" | jq -r '._TRANSPORT // empty')
  unit=$(echo "${json_line}" | jq -r '._SYSTEMD_UNIT // empty')
  syslog_id=$(echo "${json_line}" | jq -r '.SYSLOG_IDENTIFIER // empty')
  comm=$(echo "${json_line}" | jq -r '._COMM // empty')

  if [[ "${transport}" == "kernel" ]]; then
    echo "Kernel (dmesg)"
  elif [[ -n "${unit}" ]]; then
    echo "${unit}"
  elif [[ -n "${syslog_id}" ]]; then
    echo "${syslog_id}"
  elif [[ -n "${comm}" ]]; then
    echo "${comm}"
  else
    echo "system"
  fi
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

  local view_cmd="pkexec journalctl --cursor=\"${cursor}\" -n 50 -xb; echo; read -n 1 -s -r -p 'Press any key to close...'"

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
  local journal_args=("-b" "-p" "${PRIORITY}" "-o" "json")

  if [[ -f "${CURSOR_FILE}" && -s "${CURSOR_FILE}" ]]; then
    local saved_cursor
    saved_cursor=$(cat "${CURSOR_FILE}" | tr -d '\n\r ')
    if [[ -n "${saved_cursor}" ]]; then
      journal_args+=("--after-cursor=${saved_cursor}")
    fi
  else
    # If no cursor file exists yet, start from current boot tail so we don't alert on past history
    # Save the current end cursor first
    mkdir -p "$(dirname "${CURSOR_FILE}")"
    local initial_cursor
    initial_cursor=$(journalctl -b -n 1 --show-cursor 2>/dev/null | grep -E '^-- cursor:' | awk '{print $3}' || true)
    if [[ -n "${initial_cursor}" ]]; then
      if [[ "${DRY_RUN}" != "true" ]]; then
        echo "${initial_cursor}" > "${CURSOR_FILE}"
      else
        echo "[warnify] (dry-run) Initial cursor position: ${initial_cursor}"
      fi
      return 0
    fi
  fi

  local raw_events=()
  while IFS= read -r line; do
    if [[ -n "${line}" ]]; then
      raw_events+=("${line}")
    fi
  done < <(journalctl "${journal_args[@]}" 2>/dev/null || true)

  local count="${#raw_events[@]}"
  if [[ "${count}" -eq 0 ]]; then
    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "[warnify] No new warnings or errors detected since cursor."
    fi
    return 0
  fi

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[warnify] Detected ${count} new warning/error event(s):"
  fi

  local first_cursor=""
  local last_cursor=""
  local categories=()
  local last_msg=""
  local last_time=""
  local last_source=""

  for event in "${raw_events[@]}"; do
    local cur msg raw_time source
    cur=$(echo "${event}" | jq -r '.__CURSOR // empty')
    msg=$(echo "${event}" | jq -r '.MESSAGE // empty')
    raw_time=$(echo "${event}" | jq -r '.__REALTIME_TIMESTAMP // empty')
    source=$(classify_event "${event}")

    [[ -z "${first_cursor}" ]] && first_cursor="${cur}"
    [[ -n "${cur}" ]] && last_cursor="${cur}"

    categories+=("${source}")
    last_msg="${msg}"
    last_time=$(format_timestamp "${raw_time}")
    last_source="${source}"

    if [[ "${DRY_RUN}" == "true" ]]; then
      echo "  • [${last_time}] [${source}] ${msg:0:80}"
    fi
  done

  # Build notification
  if [[ "${DRY_RUN}" != "true" ]]; then
    local title=""
    local body=""

    if [[ "${count}" -eq 1 ]]; then
      title="⚠️ System Warning: [${last_source}]"
      body="Time: ${last_time}\nSource: ${last_source}\n\n${last_msg:0:140}"
    else
      # Summarize categories
      local summary
      summary=$(printf "%s\n" "${categories[@]}" | sort | uniq -c | awk '{print $2 ": " $1}' | paste -sd ", " -)
      title="⚠️ ${count} System Warnings Detected"
      body="Time: ${last_time}\nBreakdown: ${summary}\nLatest: ${last_msg:0:100}"
    fi

    # Dispatch notification asynchronously so cursor update is immediate
    send_notification "${title}" "${body}" "${first_cursor}" &

    # Update cursor state
    if [[ -n "${last_cursor}" ]]; then
      mkdir -p "$(dirname "${CURSOR_FILE}")"
      echo "${last_cursor}" > "${CURSOR_FILE}"
    fi
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
Description=warnify - Run journal warning monitor every minute
After=network.target

[Timer]
OnCalendar=*:0/1
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
Description=warnify - Run journal warning monitor every minute
After=network.target

[Timer]
OnCalendar=*:0/1
AccuracySec=5s
Persistent=true

[Install]
WantedBy=timers.target
EOF

  mkdir -p /var/lib/warnify
  chmod 644 "${service_file}" "${timer_file}"
  systemctl daemon-reload
  systemctl enable --now warnify.timer
  echo "Successfully installed and enabled warnify.timer (running every 1 minute)."
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
  echo "Cursor file: ${CURSOR_FILE}"
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
    -o|--once)
      ONCE_MODE=true
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
      # Internal test helper: read stdin and classify
      while IFS= read -r line; do
        classify_event "$line"
      done
      exit 0
      ;;
    --test-process-events)
      # Internal test helper: takes cursor file and processes events from stdin
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
scan_journal
