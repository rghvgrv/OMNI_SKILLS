#!/usr/bin/env bats
# Slice 3+: install.sh copies skill files to detected agent dirs.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  INSTALL="$ROOT/install.sh"
  TMPHOME="$(mktemp -d)"
  export HOME="$TMPHOME"
  export USERPROFILE="$TMPHOME"
  export CLAUDE_CONFIG_DIR=""
}

teardown() {
  rm -rf "$TMPHOME"
}

# --- Slice 3 ---

@test "install.sh exists and is executable" {
  [ -f "$INSTALL" ]
  [ -x "$INSTALL" ] || chmod +x "$INSTALL"
  [ -x "$INSTALL" ]
}

@test "install.sh copies skills to ~/.claude/skills when Claude dir present" {
  mkdir -p "$TMPHOME/.claude"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$TMPHOME/.claude/skills/clock/clock.sh" ]
  [ -f "$TMPHOME/.claude/skills/clock/skill.md" ]
  [ -f "$TMPHOME/.claude/skills/system-stats/stats.sh" ]
  [ -f "$TMPHOME/.claude/skills/system-stats/skill.md" ]
}

@test "install.sh exits 1 with no agents detected (negative)" {
  run bash "$INSTALL"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "no agents detected" ]]
}

# --- Slice 5: settings.json hook merge ---

@test "install.sh wires SessionStart hook into ~/.claude/settings.json" {
  mkdir -p "$TMPHOME/.claude"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$TMPHOME/.claude/settings.json" ]
  grep -q '"SessionStart"' "$TMPHOME/.claude/settings.json"
  grep -q 'omni-skills' "$TMPHOME/.claude/settings.json"
}

@test "install.sh preserves existing settings.json keys (negative: no clobber)" {
  mkdir -p "$TMPHOME/.claude"
  printf '{"theme":"dark","mySetting":42}\n' > "$TMPHOME/.claude/settings.json"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  grep -q '"theme": *"dark"' "$TMPHOME/.claude/settings.json"
  grep -q '"mySetting": *42' "$TMPHOME/.claude/settings.json"
}

@test "install.sh re-run does not duplicate SessionStart hook" {
  mkdir -p "$TMPHOME/.claude"
  bash "$INSTALL" >/dev/null
  bash "$INSTALL" >/dev/null
  count=$(grep -c 'omni-skills' "$TMPHOME/.claude/settings.json" || true)
  [ "$count" -eq 2 ]   # one in command, one in statusMessage; total fixed = 2
}

@test "install.sh exits non-zero on malformed settings.json (negative)" {
  mkdir -p "$TMPHOME/.claude"
  printf '{not json' > "$TMPHOME/.claude/settings.json"
  run bash "$INSTALL"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "settings.json" ]]
  # original preserved (no overwrite on parse fail)
  run cat "$TMPHOME/.claude/settings.json"
  [[ "$output" =~ "{not json" ]]
}

# --- Slice 6: Gemini extension manifest ---

@test "install.sh writes gemini-extension.json when ~/.gemini present" {
  mkdir -p "$TMPHOME/.gemini"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$TMPHOME/.gemini/extensions/clock/gemini-extension.json" ]
  [ -f "$TMPHOME/.gemini/extensions/system-stats/gemini-extension.json" ]
  grep -q '"name": *"clock"' "$TMPHOME/.gemini/extensions/clock/gemini-extension.json"
  grep -q '"name": *"system-stats"' "$TMPHOME/.gemini/extensions/system-stats/gemini-extension.json"
}

@test "install.sh skips Gemini cleanly when ~/.gemini absent (negative)" {
  mkdir -p "$TMPHOME/.claude"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ ! -d "$TMPHOME/.gemini" ]
}

# --- Slice 7: Cursor rule mdc ---

@test "install.sh writes Cursor rule mdc files when ~/.cursor present" {
  mkdir -p "$TMPHOME/.cursor"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$TMPHOME/.cursor/rules/clock.mdc" ]
  [ -f "$TMPHOME/.cursor/rules/system-stats.mdc" ]
  grep -q '^---' "$TMPHOME/.cursor/rules/clock.mdc"
  grep -q 'clock.sh' "$TMPHOME/.cursor/rules/clock.mdc"
}

@test "install.sh preserves user-edited Cursor rule (negative: no overwrite without --force)" {
  mkdir -p "$TMPHOME/.cursor/rules"
  printf 'USER_CONTENT\n' > "$TMPHOME/.cursor/rules/clock.mdc"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  grep -q USER_CONTENT "$TMPHOME/.cursor/rules/clock.mdc"
}

# --- Slice 8: Codex AGENTS.md ---

@test "install.sh appends OMNI_SKILLS block to ~/.codex/AGENTS.md" {
  mkdir -p "$TMPHOME/.codex"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$TMPHOME/.codex/AGENTS.md" ]
  grep -q '<!-- omni-skills:begin -->' "$TMPHOME/.codex/AGENTS.md"
  grep -q '<!-- omni-skills:end -->' "$TMPHOME/.codex/AGENTS.md"
  grep -q 'clock' "$TMPHOME/.codex/AGENTS.md"
}

@test "install.sh re-run does not duplicate Codex AGENTS.md block" {
  mkdir -p "$TMPHOME/.codex"
  bash "$INSTALL" >/dev/null
  bash "$INSTALL" >/dev/null
  count=$(grep -c '<!-- omni-skills:begin -->' "$TMPHOME/.codex/AGENTS.md")
  [ "$count" -eq 1 ]
}

@test "install.sh preserves pre-existing AGENTS.md content (negative)" {
  mkdir -p "$TMPHOME/.codex"
  printf '# my notes\n\nkeep this line\n' > "$TMPHOME/.codex/AGENTS.md"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  grep -q 'keep this line' "$TMPHOME/.codex/AGENTS.md"
}

# --- Slice 9: --agent flag ---

@test "install.sh --agent gemini installs only to Gemini even with Claude present" {
  mkdir -p "$TMPHOME/.claude" "$TMPHOME/.gemini"
  run bash "$INSTALL" --agent gemini
  [ "$status" -eq 0 ]
  [ -f "$TMPHOME/.gemini/extensions/clock/clock.sh" ]
  [ ! -d "$TMPHOME/.claude/skills" ]
}

@test "install.sh --agent unknown exits 2 (negative)" {
  run bash "$INSTALL" --agent foobar
  [ "$status" -eq 2 ]
  [[ "$output" =~ "unknown agent" ]]
}

@test "install.sh --agent claude with no claude dir exits 1 (negative)" {
  run bash "$INSTALL" --agent claude
  [ "$status" -eq 1 ]
}

# --- Slice 4: idempotency ---

@test "install.sh re-run skips existing skills without --force" {
  mkdir -p "$TMPHOME/.claude"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "skip clock" ]]
  [[ "$output" =~ "skip system-stats" ]]
}

@test "install.sh --force overwrites existing skills" {
  mkdir -p "$TMPHOME/.claude"
  bash "$INSTALL" >/dev/null
  echo "STALE" > "$TMPHOME/.claude/skills/clock/clock.sh"
  run bash "$INSTALL" --force
  [ "$status" -eq 0 ]
  run cat "$TMPHOME/.claude/skills/clock/clock.sh"
  [[ ! "$output" =~ "STALE" ]]
  [[ "$output" =~ "Current Date" ]]
}
