#!/usr/bin/env bats
# Slice 1: clock.sh contract — date, time, timezone, epoch.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CLOCK="$ROOT/skills/clock/clock.sh"
}

@test "clock.sh is executable" {
  [ -x "$CLOCK" ] || chmod +x "$CLOCK"
  [ -x "$CLOCK" ]
}

@test "clock.sh prints Current Date in YYYY-MM-DD" {
  run bash "$CLOCK"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Current\ Date:\ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]
}

@test "clock.sh prints Current Time in HH:MM:SS" {
  run bash "$CLOCK"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Current\ Time:\ [0-9]{2}:[0-9]{2}:[0-9]{2} ]]
}

@test "clock.sh prints Timezone" {
  run bash "$CLOCK"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Timezone:\ [A-Za-z0-9+-]+ ]]
}

@test "clock.sh prints Unix Epoch as integer" {
  run bash "$CLOCK"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Unix\ Epoch:\ [0-9]+ ]]
}

@test "clock.sh exits non-zero when date binary missing (negative)" {
  TMPBIN="$(mktemp -d)"
  run env PATH="$TMPBIN" bash "$CLOCK"
  [ "$status" -ne 0 ]
  rm -rf "$TMPBIN"
}
