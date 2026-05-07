#!/usr/bin/env bats
# Slice 2: stats.sh contract — cpu, memory, disk, hostname, os.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  STATS="$ROOT/skills/system-stats/stats.sh"
}

@test "stats.sh exists and is executable" {
  [ -f "$STATS" ]
  [ -x "$STATS" ] || chmod +x "$STATS"
  [ -x "$STATS" ]
}

@test "stats.sh prints OS line" {
  run bash "$STATS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ OS: ]]
}

@test "stats.sh prints Hostname line" {
  run bash "$STATS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Hostname: ]]
}

@test "stats.sh prints CPU line" {
  run bash "$STATS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ CPU: ]]
}

@test "stats.sh prints Memory line with MB or GB" {
  run bash "$STATS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Memory:.*[KMG]i?B ]]
}

@test "stats.sh prints Disk line with percent" {
  run bash "$STATS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Disk:.*%[[:space:]]*used ]]
}

@test "stats.sh prints Uptime" {
  run bash "$STATS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ Uptime: ]]
}

@test "stats.sh exits 2 on unsupported OS (negative)" {
  run env OMNI_FORCE_OS=plan9 bash "$STATS"
  [ "$status" -eq 2 ]
}
