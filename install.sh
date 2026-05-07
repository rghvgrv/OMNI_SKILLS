#!/usr/bin/env bash
# OMNI_SKILLS universal installer — copies skills into detected AI agent config dirs.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.sh | bash
#   bash install.sh                # detect + install everywhere present
#   bash install.sh --force        # overwrite existing
#   bash install.sh --agent <name> # claude|gemini|cursor|codex|generic
set -eu

FORCE=0
ONLY_AGENT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force|-f) FORCE=1; shift ;;
    --agent) ONLY_AGENT="${2:-}"; shift 2 ;;
    --agent=*) ONLY_AGENT="${1#*=}"; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

VALID_AGENTS="claude gemini cursor codex generic"
if [ -n "$ONLY_AGENT" ]; then
  case " $VALID_AGENTS " in *" $ONLY_AGENT "*) ;; *)
    echo "unknown agent: $ONLY_AGENT (valid: $VALID_AGENTS)" >&2; exit 2 ;;
  esac
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"

# Cross-platform HOME (Windows uses USERPROFILE)
HOME_DIR="${HOME:-${USERPROFILE:-}}"
[ -z "$HOME_DIR" ] && { echo "cannot determine HOME" >&2; exit 1; }

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME_DIR/.claude}"
GEMINI_DIR="$HOME_DIR/.gemini"
CURSOR_DIR="$HOME_DIR/.cursor"
CODEX_DIR="$HOME_DIR/.codex"
GENERIC_DIR="$HOME_DIR/.agents"

# Skill list — names match dirs under skills/
SKILL_NAMES="clock system-stats"

want() {
  # $1 = agent name; return 0 if installer should run for that agent
  [ -z "$ONLY_AGENT" ] && return 0
  [ "$ONLY_AGENT" = "$1" ]
}

detect() {
  # $1 = agent dir; return 0 if present
  [ -d "$1" ]
}

copy_skill_tree() {
  # $1 = dest dir (agent skills root)
  local dest="$1"
  mkdir -p "$dest"
  for s in $SKILL_NAMES; do
    if [ -d "$dest/$s" ] && [ "$FORCE" -eq 0 ]; then
      echo "  skip $s (exists; --force to overwrite)"
      continue
    fi
    rm -rf "$dest/$s"
    mkdir -p "$dest/$s"
    cp -R "$SKILLS_SRC/$s/." "$dest/$s/"
    echo "  installed: $dest/$s"
  done
}

INSTALLED=0

wire_claude_hook() {
  # Merges SessionStart hook into ~/.claude/settings.json via node.
  local settings="$CLAUDE_DIR/settings.json"
  if ! command -v node >/dev/null 2>&1; then
    echo "  WARN: node not found — skipping settings.json hook merge"
    return 0
  fi
  [ -f "$settings" ] || printf '{}\n' > "$settings"
  cp "$settings" "$settings.bak"
  if ! OMNI_SETTINGS="$settings" OMNI_SKILLS_DIR="$CLAUDE_DIR/skills" OMNI_HOOK_TAG="omni-skills" \
        node "$REPO_ROOT/merge-settings.js"; then
    echo "  ERROR: settings.json merge failed; original preserved at $settings.bak" >&2
    cp "$settings.bak" "$settings"
    return 3
  fi
}

# --- Claude Code ---
if want claude && detect "$CLAUDE_DIR"; then
  echo "Claude Code detected: $CLAUDE_DIR"
  copy_skill_tree "$CLAUDE_DIR/skills"
  wire_claude_hook || exit $?
  INSTALLED=$((INSTALLED + 1))
fi

write_gemini_manifest() {
  # $1 = skill name; $2 = dest dir
  local name="$1" dest="$2"
  local desc
  desc="$(awk -F'> ' '/^description:/ {sub(/^description:[[:space:]]*>?[[:space:]]*/,"",$0); print; exit}' "$SKILLS_SRC/$name/skill.md" 2>/dev/null)"
  desc="${desc:-OMNI_SKILLS skill}"
  cat > "$dest/gemini-extension.json" <<EOF
{
  "name": "$name",
  "version": "1.0.0",
  "description": "$desc"
}
EOF
}

# --- Gemini CLI ---
if want gemini && detect "$GEMINI_DIR"; then
  echo "Gemini CLI detected: $GEMINI_DIR"
  copy_skill_tree "$GEMINI_DIR/extensions"
  for s in $SKILL_NAMES; do
    write_gemini_manifest "$s" "$GEMINI_DIR/extensions/$s"
  done
  INSTALLED=$((INSTALLED + 1))
fi

write_cursor_rule() {
  # $1 = skill name; $2 = dest mdc path
  local name="$1" mdc="$2"
  local script
  script="$(ls "$SKILLS_SRC/$name"/*.sh 2>/dev/null | head -n1)"
  script="$(basename "$script")"
  local desc
  desc="$(awk -F'> ' '/^description:/ {sub(/^description:[[:space:]]*>?[[:space:]]*/,"",$0); print; exit}' "$SKILLS_SRC/$name/skill.md" 2>/dev/null)"
  desc="${desc:-OMNI_SKILLS skill}"
  cat > "$mdc" <<EOF
---
description: $desc
globs:
alwaysApply: false
---

# $name

Run \`./skills/$name/$script\` from the repo root to use this skill.

See full instructions in \`skills/$name/skill.md\`.
EOF
}

# --- Cursor ---
if want cursor && detect "$CURSOR_DIR"; then
  echo "Cursor detected: $CURSOR_DIR"
  mkdir -p "$CURSOR_DIR/rules"
  for s in $SKILL_NAMES; do
    target="$CURSOR_DIR/rules/$s.mdc"
    if [ -f "$target" ] && [ "$FORCE" -eq 0 ]; then
      echo "  skip $s.mdc (exists; --force to overwrite)"
      continue
    fi
    write_cursor_rule "$s" "$target"
    echo "  installed: $target"
  done
  INSTALLED=$((INSTALLED + 1))
fi

append_agents_block() {
  # $1 = AGENTS.md path
  local md="$1"
  local begin="<!-- omni-skills:begin -->"
  local end="<!-- omni-skills:end -->"
  [ -f "$md" ] || : > "$md"
  if grep -q "$begin" "$md"; then
    # Replace existing block in place using awk (portable).
    local tmp="$md.tmp"
    awk -v b="$begin" -v e="$end" '
      $0 ~ b {skip=1}
      !skip {print}
      $0 ~ e {skip=0; next}
    ' "$md" > "$tmp"
    mv "$tmp" "$md"
  fi
  {
    printf '\n%s\n' "$begin"
    printf '## OMNI_SKILLS\n\n'
    printf 'Skills available locally:\n\n'
    for s in $SKILL_NAMES; do
      printf -- '- **%s** — see `skills/%s/skill.md` (run `./skills/%s/*.sh`)\n' "$s" "$s" "$s"
    done
    printf '\n%s\n' "$end"
  } >> "$md"
}

# --- Codex CLI ---
if want codex && detect "$CODEX_DIR"; then
  echo "Codex CLI detected: $CODEX_DIR"
  copy_skill_tree "$CODEX_DIR/skills"
  append_agents_block "$CODEX_DIR/AGENTS.md"
  echo "  installed: $CODEX_DIR/AGENTS.md (omni-skills block)"
  INSTALLED=$((INSTALLED + 1))
fi

# --- Generic ~/.agents ---
if want generic && detect "$GENERIC_DIR"; then
  echo "Generic .agents detected: $GENERIC_DIR"
  copy_skill_tree "$GENERIC_DIR/skills"
  INSTALLED=$((INSTALLED + 1))
fi

if [ "$INSTALLED" -eq 0 ]; then
  echo "no agents detected. create one of: ~/.claude ~/.gemini ~/.cursor ~/.codex ~/.agents" >&2
  exit 1
fi

echo "Done. Skills installed to $INSTALLED agent(s)."
