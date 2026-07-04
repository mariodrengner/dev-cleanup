#!/usr/bin/env bash
set -euo pipefail

PREFIX="$HOME/.local/bin"
MODE="install"
SCRIPTS=(dev-cleanup dev-sizes dev-clean dev-cache-clean)

usage() {
  printf 'Usage: ./install.sh [--prefix <dir>] [--uninstall]\n'
  printf '  --prefix <dir>  Symlink target directory (default: ~/.local/bin)\n'
  printf '  --uninstall     Remove symlinks created by this installer\n'
  printf '  --help, -h      Show this help\n'
  exit "${1:-1}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)    [[ $# -ge 2 ]] || usage; PREFIX="$2"; shift ;;
    --uninstall) MODE="uninstall" ;;
    --help|-h)   usage 0 ;;
    *)           printf 'Unknown argument: %s\n' "$1"; usage ;;
  esac
  shift
done

REPO_BIN=$(cd "$(dirname "${BASH_SOURCE[0]}")/bin" && pwd)

if [[ "$MODE" == "uninstall" ]]; then
  for s in "${SCRIPTS[@]}"; do
    link="$PREFIX/$s"
    if [[ -L "$link" && "$(readlink "$link")" == "$REPO_BIN/$s" ]]; then
      rm "$link"
      printf 'Removed %s\n' "$link"
    elif [[ -e "$link" ]]; then
      printf 'Skipped %s (not a symlink created by this installer)\n' "$link"
    fi
  done
  exit 0
fi

command -v git >/dev/null \
  || printf 'Warning: git not found — gitignore detection in dev-clean will be inactive.\n'
command -v trash >/dev/null \
  || printf 'Warning: trash not found (brew install trash) — dev-clean --delete needs it unless you use --fast.\n'

mkdir -p "$PREFIX"
for s in "${SCRIPTS[@]}"; do
  link="$PREFIX/$s"
  if [[ -e "$link" && ! -L "$link" ]]; then
    printf 'Skipped %s (file exists and is not a symlink)\n' "$link"
    continue
  fi
  ln -sf "$REPO_BIN/$s" "$link"
  printf 'Linked %s -> %s\n' "$link" "$REPO_BIN/$s"
done

case ":$PATH:" in
  *":$PREFIX:"*) ;;
  *) printf '\nNote: %s is not in your PATH. Add this to your shell profile:\n' "$PREFIX"
     printf '  export PATH="%s:$PATH"\n' "$PREFIX" ;;
esac
printf 'Done.\n'
