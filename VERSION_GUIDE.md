# Semantic Versioning Guide (SemVer)

## Overview

All scripts and packages in this repository adhere to **Semantic Versioning 2.0.0** (SemVer). The formal specification is defined at [semver.org's specification page](https://semver.org/spec/v2.0.0.html)

---

## Format: `MAJOR.MINOR.PATCH`

A Semantic Version number takes the form:

```
v<MAJOR>.<MINOR>.<PATCH>
```

*(e.g., `v0.1.0`, `v1.0.0`, `v1.4.2`)*

| Component | Meaning | When to Increment |
|---|---|---|
| **MAJOR** | Breaking / incompatible changes | Incremented when incompatible API, CLI flag, or architectural changes are introduced. |
| **MINOR** | New backward-compatible functionality | Incremented when new features, commands, or non-breaking options are added. |
| **PATCH** | Backward-compatible bug fixes | Incremented when bug fixes, performance improvements, or documentation fixes are applied without changing behavior. |

---

## Core Rules

1. **Initial Release**: All new scripts start development at `v0.1.0`.
   - `0.x.y` indicates initial development; minor versions may evolve as features solidify.
2. **Plain Integers**: Never use leading zeros in integers (e.g., `v0.1.0`, NOT `v0.01.0`).
3. **Dot Separator**: Always use dot separators for patch releases (e.g., `v0.2.1`, NOT `v0.2-1`).
4. **Pre-release Tags**: Pre-release tags may be appended with a hyphen when necessary (e.g., `v1.0.0-alpha.1`, `v1.0.0-rc.1`).
5. **Stable API (`v1.0.0`)**: Once the script is public, production-ready, and stabilized for external users, release `v1.0.0`.

---

## Progression Lifecycle Example

| Step | State / Event | Version Tag |
|---|---|---|
| 1 | Initial public release / milestone | `v0.1.0` |
| 2 | Added new feature or options | `v0.2.0` |
| 3 | Bugfix / patch release | `v0.2.1` |
| 4 | Additional backward-compatible features | `v0.3.0` |
| 5 | Public stable baseline release | `v1.0.0` |
| 6 | Backward-compatible enhancement | `v1.1.0` |
| 7 | Hotfix / patch | `v1.1.1` |
| 8 | Breaking change / major redesign | `v2.0.0` |

---

## Git Tagging Commands

```bash
# Create an annotated git tag
git tag -a v0.1.0 -m "Release v0.1.0: Initial release"

# Push the tag to remote
git push origin v0.1.0
```
