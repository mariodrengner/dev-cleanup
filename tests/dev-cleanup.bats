#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d)
  export HOME="$TMP"
  WS="$TMP/dev"
  mkdir -p "$WS"
  BIN="$BATS_TEST_DIRNAME/../bin"
  # Minimal-PATH für den all-Test: nur benötigte Kern-Tools, damit
  # dev-cache-clean keine echten Caches anfasst (brew/npm/docker/xcrun fehlen)
  FAKEBIN="$TMP/fakebin"
  mkdir -p "$FAKEBIN"
  local c
  for c in bash find du awk sort cut tr wc git dirname basename mktemp touch rm readlink cat grep sed; do
    p=$(command -v "$c") && ln -s "$p" "$FAKEBIN/$c"
  done
  # trash-Stub auch im FAKEBIN — dev-clean --delete prüft trash VOR dem Scan
  printf '#!/usr/bin/env bash\nrm -rf "$@"\n' > "$FAKEBIN/trash"
  chmod +x "$FAKEBIN/trash"
}

teardown() { rm -rf "$TMP"; }

@test "--version prints name and version" {
  run "$BIN/dev-cleanup" --version
  [ "$status" -eq 0 ]
  [[ "$output" == "dev-cleanup 1.0.0" ]]
}

@test "--help lists all commands and exits 0" {
  run "$BIN/dev-cleanup" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Commands:"* ]]
  [[ "$output" == *"sizes"* && "$output" == *"clean"* ]]
  [[ "$output" == *"cache"* && "$output" == *"all"* ]]
}

@test "no arguments shows usage and exits 1" {
  run "$BIN/dev-cleanup"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: dev-cleanup"* ]]
}

@test "unknown command exits 1" {
  run "$BIN/dev-cleanup" frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command"* ]]
}

@test "sizes dispatches to dev-sizes" {
  mkdir -p "$WS/proj/node_modules"
  run "$BIN/dev-cleanup" sizes "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Artifacts by type"* ]]
}

@test "clean passes arguments through (dry-run)" {
  mkdir -p "$WS/proj/node_modules"
  run "$BIN/dev-cleanup" clean "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DRY RUN]"* ]]
  [ -d "$WS/proj/node_modules" ]
}

@test "help clean shows dev-clean usage" {
  run "$BIN/dev-cleanup" help clean
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dev-clean"* ]]
}

@test "cache --help shows dev-cache-clean usage" {
  run "$BIN/dev-cleanup" cache --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dev-cache-clean"* ]]
}

@test "all rejects flags" {
  run "$BIN/dev-cleanup" all --fast
  [ "$status" -eq 1 ]
  [[ "$output" == *"accepts only a directory"* ]]
}

@test "all rejects more than one directory" {
  run "$BIN/dev-cleanup" all "$WS" "$WS"
  [ "$status" -eq 1 ]
}

@test "all runs three steps on empty workspace" {
  run env PATH="$FAKEBIN" "$BIN/dev-cleanup" all "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[1/3]"* ]]
  [[ "$output" == *"No artifacts found"* ]]
  [[ "$output" == *"[3/3]"* ]]
  [[ "$output" == *"Done!"* ]]
}

@test "works when invoked via symlink" {
  mkdir -p "$TMP/linkbin"
  ln -s "$BIN/dev-cleanup" "$TMP/linkbin/dev-cleanup"
  run "$TMP/linkbin/dev-cleanup" --version
  [ "$status" -eq 0 ]
  [[ "$output" == "dev-cleanup 1.0.0" ]]
}
