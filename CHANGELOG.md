# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `dev-clean --yes`/`-y` answers the confirmations for scripts and agents; refused together with `--fast`
- `dev-clean` accepts several target directories; each is validated before scanning, overlapping targets list a directory once

### Changed
- `dev-clean` always prints the `Found N artifact directories (…)` and `Total reclaimable` lines, also when nothing is found

### Fixed
- `dev-clean --delete` with a closed stdin exited silently with status 1; it now prints `Aborted.` and exits 0
- `dev-clean` ignored every target but the last when given several
- The "missing trash" test works on macOS 15+, which ships `/usr/bin/trash`

## [1.0.0] - 2026-07-03

### Added
- `dev-sizes` — read-only analysis of build-artifact disk usage (by type and per project)
- `dev-clean` — dry-run-by-default artifact removal with trash (recoverable) or `rm -rf`;
  generic directory names (vendor, deps, target, …) are only deleted when a stack marker
  file or a gitignore match confirms them
- `dev-cache-clean` — sequential cache cleanup (Homebrew, Yarn, npm, pip, Composer, Bun,
  Docker, Flutter, Xcode DerivedData, iOS simulators) with confirmations for destructive steps
- `dev-cleanup` — dispatcher with `sizes`, `clean`, `cache`, `all`, `help`, `--version`
- `install.sh` — symlink installer with `--prefix` and `--uninstall`
- CI: ShellCheck + Bats on macOS and Ubuntu
