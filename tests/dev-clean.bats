#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d)
  export HOME="$TMP"
  WS="$TMP/dev"
  mkdir -p "$WS"
  STUB="$TMP/stubbin"
  mkdir -p "$STUB"
  printf '#!/usr/bin/env bash\nrm -rf "$@"\n' > "$STUB/trash"
  chmod +x "$STUB/trash"
  export PATH="$STUB:$PATH"
  BIN="$BATS_TEST_DIRNAME/../bin"
}

teardown() { rm -rf "$TMP"; }

# --- Dry-Run & Basis ---

@test "dry-run lists node_modules but deletes nothing" {
  mkdir -p "$WS/proj/node_modules"
  run "$BIN/dev-clean" "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DRY RUN]"* ]]
  [[ "$output" == *node_modules* ]]
  [ -d "$WS/proj/node_modules" ]
}

@test "no artifacts found exits 0 with consistent summary" {
  run "$BIN/dev-clean" "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 0 artifact directories (0K)"* ]]
  [[ "$output" == *"Total reclaimable: 0K"* ]]
  [[ "$output" == *"No artifacts found"* ]]
}

@test "--delete with no artifacts prints summary and nothing to delete" {
  run "$BIN/dev-clean" --delete "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 0 artifact directories (0K)"* ]]
  [[ "$output" == *"Nothing to delete."* ]]
}

@test "--delete removes node_modules after confirmation" {
  mkdir -p "$WS/proj/node_modules"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 directories deleted"* ]]
  [ ! -d "$WS/proj/node_modules" ]
}

@test "answering n aborts deletion" {
  mkdir -p "$WS/proj/node_modules"
  run bash -c "printf 'n\n' | '$BIN/dev-clean' --delete '$WS'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aborted"* ]]
  [ -d "$WS/proj/node_modules" ]
}

@test "--delete --yes removes without reading stdin" {
  mkdir -p "$WS/proj/node_modules"
  run bash -c "'$BIN/dev-clean' --delete --yes '$WS' </dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 directories deleted"* ]]
  [[ "$output" != *"Delete 1 directories?"* ]]
  [ ! -d "$WS/proj/node_modules" ]
}

@test "-y is an alias for --yes" {
  mkdir -p "$WS/proj/node_modules"
  run bash -c "'$BIN/dev-clean' -y --delete '$WS' </dev/null"
  [ "$status" -eq 0 ]
  [ ! -d "$WS/proj/node_modules" ]
}

@test "--delete on EOF stdin aborts cleanly" {
  mkdir -p "$WS/proj/node_modules"
  run bash -c "'$BIN/dev-clean' --delete '$WS' </dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Aborted"* ]]
  [ -d "$WS/proj/node_modules" ]
}

@test "--yes cannot be combined with --fast" {
  mkdir -p "$WS/proj/node_modules"
  run "$BIN/dev-clean" --delete --fast --yes "$WS"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--yes cannot be combined with --fast"* ]]
  [ -d "$WS/proj/node_modules" ]
}

@test "--yes without --delete stays a dry-run" {
  mkdir -p "$WS/proj/node_modules"
  run "$BIN/dev-clean" --yes "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DRY RUN]"* ]]
  [ -d "$WS/proj/node_modules" ]
}

# --- Mehrere Ziele ---

@test "two targets are both scanned" {
  mkdir -p "$WS/a/node_modules" "$WS/b/node_modules"
  run "$BIN/dev-clean" "$WS/a" "$WS/b"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 2 artifact directories"* ]]
  [[ "$output" == *"/a/node_modules"* ]]
  [[ "$output" == *"/b/node_modules"* ]]
}

@test "two targets are both cleaned with --delete --yes" {
  mkdir -p "$WS/a/node_modules" "$WS/b/.venv"
  run "$BIN/dev-clean" --delete --yes "$WS/a" "$WS/b"
  [ "$status" -eq 0 ]
  [ ! -d "$WS/a/node_modules" ]
  [ ! -d "$WS/b/.venv" ]
}

@test "overlapping targets list each directory once" {
  mkdir -p "$WS/a/node_modules"
  run "$BIN/dev-clean" "$WS" "$WS/a"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Found 1 artifact directories"* ]]
}

@test "a guarded target among several aborts before scanning" {
  mkdir -p "$WS/a/node_modules"
  run "$BIN/dev-clean" --delete --yes "$WS/a" "$HOME"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not allowed as a target"* ]]
  [ -d "$WS/a/node_modules" ]
}

@test "a missing target among several aborts" {
  run "$BIN/dev-clean" "$WS" "$WS/nope"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Directory not found"* ]]
}

# --- Marker-Erkennung ---

@test "vendor with composer.json marker is deleted" {
  mkdir -p "$WS/php/vendor/pkg"; touch "$WS/php/composer.json"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/php/vendor" ]
}

@test "vendor with go.mod marker is deleted" {
  mkdir -p "$WS/go/vendor/pkg"; touch "$WS/go/go.mod"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/go/vendor" ]
}

@test "deps and _build with mix.exs marker are deleted" {
  mkdir -p "$WS/ex/deps/x" "$WS/ex/_build/x"; touch "$WS/ex/mix.exs"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/ex/deps" ]
  [ ! -d "$WS/ex/_build" ]
}

@test "venv with pyvenv.cfg is deleted, bare venv is skipped" {
  mkdir -p "$WS/py1/venv"; touch "$WS/py1/venv/pyvenv.cfg"
  mkdir -p "$WS/py2/venv/src"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/py1/venv" ]
  [ -d "$WS/py2/venv" ]
}

@test "target with Cargo.toml marker is deleted" {
  mkdir -p "$WS/rust/target/debug"; touch "$WS/rust/Cargo.toml"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/rust/target" ]
}

@test "vendor with Gemfile marker is deleted" {
  mkdir -p "$WS/ruby/vendor/bundle"; touch "$WS/ruby/Gemfile"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/ruby/vendor" ]
}

@test ".build with Package.swift marker is deleted, bare .build is skipped" {
  mkdir -p "$WS/swift/.build/x"; touch "$WS/swift/Package.swift"
  mkdir -p "$WS/other/.build/x"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/swift/.build" ]
  [ -d "$WS/other/.build" ]
}

@test "obj with csproj marker is deleted, obj without is skipped" {
  mkdir -p "$WS/net/obj"; touch "$WS/net/App.csproj"
  mkdir -p "$WS/art/obj"; touch "$WS/art/obj/model.obj"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/net/obj" ]
  [ -d "$WS/art/obj" ]
}

# --- Gitignore-Fallback ---

@test "gitignored build is deleted" {
  mkdir -p "$WS/web/build"; git -C "$WS/web" init -q
  echo build > "$WS/web/.gitignore"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/web/build" ]
}

@test "global core.excludesFile is honored" {
  mkdir -p "$WS/web/dist"; git -C "$WS/web" init -q
  echo dist > "$TMP/gitignore_global"
  git config --global core.excludesFile "$TMP/gitignore_global"
  run bash -c "printf 'y\n' | '$BIN/dev-clean' --delete '$WS'"
  [ ! -d "$WS/web/dist" ]
}

@test "non-gitignored dist is skipped with label" {
  mkdir -p "$WS/web/dist"; git -C "$WS/web" init -q
  run "$BIN/dev-clean" "$WS"
  [[ "$output" == *"[skipped — no marker, not gitignored]"* ]]
}

@test "--delete with only skipped entries exits without prompting" {
  mkdir -p "$WS/web/dist"; git -C "$WS/web" init -q
  run "$BIN/dev-clean" --delete "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[skipped — no marker, not gitignored]"* ]]
  [[ "$output" == *"Nothing to delete."* ]]
  [[ "$output" != *"Delete 0 directories"* ]]
  [ -d "$WS/web/dist" ]
}

@test "dist inside node_modules is not scanned" {
  mkdir -p "$WS/proj/node_modules/pkg/dist"
  run "$BIN/dev-clean" "$WS"
  [[ "$output" != *"pkg/dist"* ]]
}

# --- Guards ---

@test "refuses / as target" {
  run "$BIN/dev-clean" --delete /
  [ "$status" -eq 1 ]
  [[ "$output" == *"not allowed as a target"* ]]
}

@test "refuses HOME as target" {
  run "$BIN/dev-clean" "$HOME"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not allowed as a target"* ]]
}

@test "target outside HOME requires extra confirmation" {
  OUT=$(mktemp -d)
  mkdir -p "$OUT/node_modules"
  run bash -c "printf 'n\n' | '$BIN/dev-clean' --delete '$OUT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"outside"* ]]
  [[ "$output" == *"Aborted"* ]]
  [ -d "$OUT/node_modules" ]
  rm -rf "$OUT"
}

@test "path with tab is skipped and reported" {
  mkdir -p "$WS/evil"$'\t'"x/node_modules"
  run "$BIN/dev-clean" "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped (control characters in path)"* ]]
}

@test "--fast without --delete prints a note" {
  run "$BIN/dev-clean" --fast "$WS"
  [[ "$output" == *"only take effect together with --delete"* ]]
}

@test "missing trash aborts before scanning" {
  mkdir -p "$WS/proj/node_modules"
  # macOS 15+ ships /usr/bin/trash, so PATH=/usr/bin:/bin is not enough:
  # mirror the system tools without trash
  NOTRASH="$TMP/notrash"; mkdir -p "$NOTRASH"
  ln -s /usr/bin/* "$NOTRASH/" 2>/dev/null || true
  ln -s /bin/* "$NOTRASH/" 2>/dev/null || true
  rm -f "$NOTRASH/trash"
  run env PATH="$NOTRASH" HOME="$HOME" "$BIN/dev-clean" --delete "$WS" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"trash is not installed"* ]]
  [ -d "$WS/proj/node_modules" ]
}

@test "--help exits 0" {
  run "$BIN/dev-clean" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dev-clean"* ]]
}
