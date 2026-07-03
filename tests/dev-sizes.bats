#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d)
  export HOME="$TMP"
  WS="$TMP/dev"
  mkdir -p "$WS"
  BIN="$BATS_TEST_DIRNAME/../bin"
}

teardown() { rm -rf "$TMP"; }

@test "dev-sizes --help exits 0 and shows usage" {
  run "$BIN/dev-sizes" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dev-sizes"* ]]
  [[ "$output" == *"Deletes nothing"* ]]
}

@test "dev-sizes unknown flag exits 1" {
  run "$BIN/dev-sizes" --nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown flag"* ]]
}

@test "dev-sizes missing directory exits 1" {
  run "$BIN/dev-sizes" "$TMP/does-not-exist"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Directory not found"* ]]
}

@test "dev-sizes empty directory exits 0" {
  run "$BIN/dev-sizes" "$WS"
  [ "$status" -eq 0 ]
}

@test "dev-sizes aggregates by type and project" {
  mkdir -p "$WS/proj-a/node_modules/pkg" "$WS/proj-b/node_modules"
  dd if=/dev/zero of="$WS/proj-a/node_modules/pkg/blob" bs=1024 count=64 2>/dev/null
  run "$BIN/dev-sizes" "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Artifacts by type"* ]]
  [[ "$output" == *"node_modules"* ]]
  [[ "$output" == *"(2 directories)"* ]]
  [[ "$output" == *"Per project"* ]]
  [[ "$output" == *"proj-a"* ]]
}

@test "dev-sizes marks conditional types with asterisk" {
  mkdir -p "$WS/proj/dist"
  run "$BIN/dev-sizes" "$WS"
  [[ "$output" == *"dist"* ]]
  [[ "$output" == *"* conditional:"* ]]
}

@test "dev-sizes does not scan dist inside node_modules" {
  mkdir -p "$WS/proj/node_modules/pkg/dist"
  run "$BIN/dev-sizes" "$WS"
  [[ "$output" == *"node_modules"* ]]
  [[ "$output" != *"pkg/dist"* ]]
}

@test "dev-sizes skips paths with control characters" {
  mkdir -p "$WS/evil"$'\t'"x/node_modules"
  run "$BIN/dev-sizes" "$WS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped (control characters in path)"* ]]
}
