# dev-cleanup

[![CI](https://github.com/mariodrengner/dev-cleanup/actions/workflows/ci.yml/badge.svg)](https://github.com/mariodrengner/dev-cleanup/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Reclaim disk space from dev build artifacts and caches — safely.

`node_modules`, Rust `target`, Python venvs, Composer `vendor`, Xcode DerivedData:
a dev directory silently accumulates gigabytes of regenerable build output.
`dev-cleanup` finds it, shows it, and removes it — dry-run by default,
recoverable via trash, and with marker-file checks so it never deletes
anything that is not a build artifact.

```
$ dev-cleanup sizes
── Artifacts by type ────────────────────────────
   4.2G  node_modules         (23 directories)
   1.8G  target               (3 directories) *
   1.1G  .venv                (6 directories)
   ...
```

## Install

```bash
git clone https://github.com/mariodrengner/dev-cleanup.git
cd dev-cleanup && ./install.sh          # symlinks into ~/.local/bin
```

`./install.sh --prefix <dir>` for a custom location, `--uninstall` to remove.

**Requirements:** bash ≥ 3.2, git (for gitignore detection).
macOS is the primary platform; the core logic is CI-tested on Linux too
(WSL behaves like Linux). For recoverable deletion install a `trash`
command — macOS: `brew install trash`, Linux: `trash-cli` — or use `--fast`.

## Usage

```bash
dev-cleanup sizes [<dir>]     # analyze artifact disk usage (read-only)
dev-cleanup clean [<dir>...]  # dry-run: show what would be deleted
dev-cleanup clean --delete    # delete via trash (recoverable)
dev-cleanup clean --delete --yes a b   # no prompt (scripts/agents; not with --fast)
dev-cleanup clean --delete --fast   # rm -rf (warning + confirmation)
dev-cleanup cache             # clean package manager & tool caches
dev-cleanup all [<dir>]       # sizes → clean --delete (safe) → cache
dev-cleanup help <command>
```

Default directory is `~/dev`. Each tool also works standalone
(`dev-sizes`, `dev-clean`, `dev-cache-clean`) — copy a single file if
that is all you need.

## What gets deleted

**Always (unambiguous artifact names):**

| Stack | Directories |
|---|---|
| Node.js | `node_modules` |
| Next.js / Nuxt / Nitro / Turbo | `.next` `.nuxt` `.output` `.nitro` `.turbo` |
| SvelteKit / Astro / Parcel / Angular | `.svelte-kit` `.astro` `.parcel-cache` `.angular` |
| General | `.cache` `coverage` |
| Python | `.venv` `__pycache__` `.pytest_cache` `.mypy_cache` `.ruff_cache` `.tox` |
| JVM / Android | `.gradle` |
| Terraform | `.terraform` |
| iOS / Flutter | `Pods` `.symlinks` `.dart_tool` |
| Haskell | `.stack-work` `dist-newstyle` |

**Conditionally (generic names — only with proof they are artifacts):**

These names collide with legitimate content (Go repos often commit `vendor/`,
`obj/` may hold 3D assets). They are only deleted when a **marker file**
identifies the stack **or** the directory is **gitignored**:

| Directory | Marker | Fallback |
|---|---|---|
| `vendor` | `composer.json` / `go.mod` / `Gemfile` next to it | gitignored |
| `deps`, `_build` | `mix.exs` next to it | gitignored |
| `venv` | `pyvenv.cfg` inside | gitignored |
| `target` | `Cargo.toml` / `pom.xml` next to it | gitignored |
| `obj` | `*.csproj` / `*.fsproj` next to it | gitignored |
| `.build` | `Package.swift` next to it | gitignored |
| `dist`, `build`, `out` | — | gitignored only |

Gitignore detection honors the project `.gitignore`, the global
`core.excludesFile`, and `.git/info/exclude`. Everything else shows up as
`[skipped — no marker, not gitignored]` with its size.

## Cache cleaning

`dev-cleanup cache` runs sequentially and skips tools that are not installed:
Homebrew, Yarn, npm, pip, Composer, Bun, Docker (`system prune -a --volumes`,
**asks first**), `flutter clean` per project, Xcode DerivedData (**asks first**),
unavailable iOS simulators.

## Safety model

- **Dry-run by default** — `clean` deletes nothing without `--delete`
- **trash by default** — deletions are recoverable; `rm -rf` requires `--fast` plus a red warning and confirmation (`--yes` is rejected together with `--fast`)
- **Non-interactive use** — `--yes` answers the prompts; without it, a closed stdin counts as "no" and aborts cleanly
- **Target guards** — `/` and `$HOME` are rejected; targets outside `$HOME` require extra confirmation
- **Marker/gitignore checks** — generic directory names need proof before deletion
- **Control-character defense** — paths containing tabs/newlines are skipped (they could corrupt the delete list); non-printable characters are masked in output
- **`all` is always safe mode** — `--fast` is deliberately unsupported there

## Contributing

PRs welcome. CI must stay green: `shellcheck bin/* install.sh` and `bats tests/`.

## License

[MIT](LICENSE)
