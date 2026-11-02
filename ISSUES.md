# Issues Ledger — warnify

All known bugs, defects, and enhancement tracking for `warnify`.

| ID | Date | Type | Severity | Status | Description |
|---|---|---|---|---|---|
| BUG-001 | 2026-11-01 | Bug | Critical | Closed | `tr` argument syntax error broke `boot_id` extraction causing perpetual boot sweep |
| BUG-002 | 2026-11-01 | Performance | Critical | Closed | O(N) process fork bomb (200k+ forks of `jq` in bash loop) froze journal scanning |
| BUG-003 | 2026-11-01 | Test | High | Closed | `test_warnify.sh` deadlocked on Test 6 due to live journal scan fork bomb |
