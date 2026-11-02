#!/usr/bin/env bash
# test_warnify.sh — Test suite for warnify
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARNIFY_BIN="${SCRIPT_DIR}/warnify.sh"
PASS=0
FAIL=0

# Helper test assertion
assert_equals() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  [PASS] $msg"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $msg (expected: '$expected', got: '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  [PASS] $msg"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $msg ('$needle' not found in output)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Running test suite for warnify ==="

# 1. Syntax check
echo "Test 1: Bash syntax verification"
if bash -n "${WARNIFY_BIN}"; then
  echo "  [PASS] warnify.sh has valid bash syntax"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] warnify.sh syntax check failed"
  FAIL=$((FAIL + 1))
fi

# 2. Executable permission check
echo "Test 2: Executable permission check"
if [[ -x "${WARNIFY_BIN}" ]]; then
  echo "  [PASS] warnify.sh is executable"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] warnify.sh is not executable"
  FAIL=$((FAIL + 1))
fi

# 3. Version output matches VERSION.md
echo "Test 3: Version flag check"
EXPECTED_VER=$(grep -E '^VERSION=' "${SCRIPT_DIR}/VERSION.md" | cut -d= -f2 | tr -d '"')
ACTUAL_VER=$("${WARNIFY_BIN}" --version 2>&1 || true)
assert_contains "${EXPECTED_VER}" "${ACTUAL_VER}" "--version output contains ${EXPECTED_VER}"

# 4. Help flag check
echo "Test 4: Help flag check"
HELP_OUT=$("${WARNIFY_BIN}" --help 2>&1 || true)
assert_contains "Usage: warnify" "${HELP_OUT}" "--help prints usage"
assert_contains "--dry-run" "${HELP_OUT}" "--help lists --dry-run"
assert_contains "--boot-sweep" "${HELP_OUT}" "--help lists --boot-sweep"
assert_contains "--daemon" "${HELP_OUT}" "--help lists --daemon"
assert_contains "--cursor-file" "${HELP_OUT}" "--help lists --cursor-file"

# 5. Invalid flag handling
echo "Test 5: Invalid flag check"
INVALID_CODE=0
"${WARNIFY_BIN}" --invalid-flag-xyz >/dev/null 2>&1 || INVALID_CODE=$?
if [[ "${INVALID_CODE}" -ne 0 ]]; then
  echo "  [PASS] Invalid flag returns non-zero exit code (${INVALID_CODE})"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Invalid flag unexpectedly returned exit code 0"
  FAIL=$((FAIL + 1))
fi

# 6. Dry run check
echo "Test 6: Dry run check"
TMP_STATE_DIR=$(mktemp -d)
DRY_RUN_OUT=$("${WARNIFY_BIN}" --dry-run --state-dir "${TMP_STATE_DIR}" 2>&1 || true)
assert_contains "warnify" "${DRY_RUN_OUT}" "Dry run outputs status header"
if [[ ! -s "${TMP_STATE_DIR}/cursor" ]]; then
  echo "  [PASS] Dry run does not write or advance cursor file"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Dry run unexpectedly modified cursor file"
  FAIL=$((FAIL + 1))
fi
rm -rf "${TMP_STATE_DIR}"

# 7. Boot sweep dry-run check
echo "Test 7: Boot sweep dry-run check"
TMP_STATE_DIR=$(mktemp -d)
BOOT_OUT=$("${WARNIFY_BIN}" --boot-sweep --dry-run --state-dir "${TMP_STATE_DIR}" 2>&1 || true)
assert_contains "Full boot-sweep" "${BOOT_OUT}" "Boot sweep mode correctly reported in dry run"
rm -rf "${TMP_STATE_DIR}"

# 8. Classification logic check
echo "Test 8: Event classification logic"
SAMPLE_KERNEL='{"_TRANSPORT":"kernel","MESSAGE":"Test kernel warning","PRIORITY":"4","__REALTIME_TIMESTAMP":"1792826779425055","__CURSOR":"c1"}'
SAMPLE_UNIT='{"_TRANSPORT":"journal","_SYSTEMD_UNIT":"bluetooth.service","MESSAGE":"Bluetooth error","PRIORITY":"3","__REALTIME_TIMESTAMP":"1792826800636738","__CURSOR":"c2"}'
SAMPLE_DAEMON='{"_TRANSPORT":"syslog","SYSLOG_IDENTIFIER":"sshd","MESSAGE":"SSH warning","PRIORITY":"4","__REALTIME_TIMESTAMP":"1792826800636738","__CURSOR":"c3"}'

PARSED_KERNEL=$("${WARNIFY_BIN}" --test-classify <<< "${SAMPLE_KERNEL}")
assert_contains "Kernel (dmesg)" "${PARSED_KERNEL}" "Kernel log classified as Kernel (dmesg)"

PARSED_UNIT=$("${WARNIFY_BIN}" --test-classify <<< "${SAMPLE_UNIT}")
assert_contains "bluetooth.service" "${PARSED_UNIT}" "Systemd unit log classified as bluetooth.service"

PARSED_DAEMON=$("${WARNIFY_BIN}" --test-classify <<< "${SAMPLE_DAEMON}")
assert_contains "sshd" "${PARSED_DAEMON}" "Syslog daemon log classified as sshd"

# 9. Cursor tracking and persistence check
echo "Test 9: Cursor persistence check"
TEST_CURSOR_FILE=$(mktemp)
"${WARNIFY_BIN}" --test-process-events "${TEST_CURSOR_FILE}" <<< "${SAMPLE_KERNEL}" >/dev/null 2>&1 || true
if [[ -f "${TEST_CURSOR_FILE}" ]] && grep -q "c1" "${TEST_CURSOR_FILE}"; then
  echo "  [PASS] Cursor successfully recorded to cursor file"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Cursor not found in cursor file"
  FAIL=$((FAIL + 1))
fi
rm -f "${TEST_CURSOR_FILE}"

# 10. Systemd unit template generation check
echo "Test 10: Systemd unit templates check"
UNITS_OUT=$("${WARNIFY_BIN}" --print-systemd-units 2>&1 || true)
assert_contains "[Unit]" "${UNITS_OUT}" "Units output contains [Unit]"
assert_contains "warnify.service" "${UNITS_OUT}" "Units output mentions warnify.service"
assert_contains "OnBootSec=1min" "${UNITS_OUT}" "Units output configures startup trigger (OnBootSec=1min)"
assert_contains "OnUnitActiveSec=2min" "${UNITS_OUT}" "Units output configures 2-minute cadence (OnUnitActiveSec=2min)"

# 11. Status command check
echo "Test 11: Status command check"
STATUS_OUT=$("${WARNIFY_BIN}" --status 2>&1 || true)
assert_contains "=== warnify Status ===" "${STATUS_OUT}" "Status output contains header"
assert_contains "Uptime:" "${STATUS_OUT}" "Status output displays uptime"
assert_contains "Current boot ID:" "${STATUS_OUT}" "Status output displays boot ID"
if [[ "${STATUS_OUT}" == *"Current boot ID: unknown"* ]]; then
  echo "  [FAIL] Current boot ID resolved as 'unknown' (tr syntax failure)"
  FAIL=$((FAIL + 1))
else
  echo "  [PASS] Current boot ID resolved to valid UUID (not unknown)"
  PASS=$((PASS + 1))
fi

echo ""
echo "=== Summary: ${PASS} passed, ${FAIL} failed ==="
if [[ "${FAIL}" -eq 0 ]]; then
  echo "All tests passed successfully!"
  exit 0
else
  echo "Some tests failed!"
  exit 1
fi
