#!/usr/bin/env bash
# OMNI_SKILLS — one-shot uninstaller (POSIX bash).
#
# One line (macOS / Linux / Git Bash):
#   curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/uninstall.sh | bash
#
# Removes OMNI_SKILLS from every detected agent. Idempotent.

set -euo pipefail

DRY=0
NO_COLOR=0
ONLY=()
REMOVED=()
SKIPPED=()
FAILED=()

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --no-color) NO_COLOR=1 ;;
    --only)
      shift
      [ $# -eq 0 ] && { echo "error: --only requires an argument" >&2; exit 2; }
      ONLY+=("$1") ;;
    -h|--help)
      cat <<'EOF'
OMNI_SKILLS uninstaller

USAGE
  uninstall.sh [flags]

FLAGS
  --dry-run         Print what would run, do nothing.
  --only <agent>    Uninstall only for the named agent. Repeatable.
  --no-color        Disable ANSI color codes.
  -h, --help        Show this help and exit.

AGENTS
  claude  gemini  cursor  codex  generic
EOF
      exit 0 ;;
    *) echo "error: unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ ! -t 1 ]; then NO_COLOR=1; fi
c_green=""; c_yellow=""; c_red=""; c_dim=""; c_reset=""
if [ "$NO_COLOR" = 0 ]; then
  c_green=$'\033[0;32m'; c_yellow=$'\033[0;33m'; c_red=$'\033[0;31m'
  c_dim=$'\033[2m'; c_reset=$'\033[0m'
fi
say()  { echo "${c_green}$*${c_reset}"; }
warn() { echo "${c_yellow}$*${c_reset}"; }
err()  { echo "${c_red}$*${c_reset}" >&2; }
note() { echo "${c_dim}$*${c_reset}"; }

only_filter() {
  local id="$1"
  [ "${#ONLY[@]}" -eq 0 ] && return 0
  local o
  for o in "${ONLY[@]+"${ONLY[@]}"}"; do
    [ "$o" = "$id" ] && return 0
  done
  return 1
}

HOME_DIR="${HOME:-${USERPROFILE:-}}"

# ── Claude Code ─────────────────────────────────────────────────────────────
remove_claude() {
  only_filter "claude" || return 0
  command -v claude >/dev/null 2>&1 || return 0
  say "→ Claude Code"
  if [ "$DRY" = 1 ]; then
    note "  [dry-run] claude plugin uninstall omni-skills@omni-skills"
    note "  [dry-run] claude plugin marketplace remove rghvgrv/OMNI_SKILLS"
    return 0
  fi
  local ok=1
  claude plugin uninstall "omni-skills@omni-skills" || ok=0
  claude plugin marketplace remove "rghvgrv/OMNI_SKILLS" || true
  [ "$ok" = 1 ] && REMOVED+=("claude") || FAILED+=("claude")
}

# ── Gemini CLI ──────────────────────────────────────────────────────────────
remove_gemini() {
  only_filter "gemini" || return 0
  command -v gemini >/dev/null 2>&1 || return 0
  say "→ Gemini CLI"
  if [ "$DRY" = 1 ]; then
    note "  [dry-run] gemini extensions uninstall omni-skills"
    return 0
  fi
  local out
  if out=$(gemini extensions uninstall omni-skills 2>&1); then
    echo "$out"
    REMOVED+=("gemini")
  else
    echo "$out"
    if echo "$out" | grep -qi "not found\|not installed"; then
      SKIPPED+=("gemini"); note "  not installed"
    else
      FAILED+=("gemini"); err "  gemini uninstall failed"
    fi
  fi
}

# ── Cursor ──────────────────────────────────────────────────────────────────
remove_cursor() {
  only_filter "cursor" || return 0
  local dir="$HOME_DIR/.cursor"
  [ -d "$dir" ] || return 0
  say "→ Cursor"
  local any=0 f
  for f in "$dir/rules/clock.mdc" "$dir/rules/system-stats.mdc"; do
    if [ -f "$f" ]; then
      any=1
      if [ "$DRY" = 1 ]; then note "  [dry-run] rm $f"
      else rm -f "$f"; note "  removed: $f"; fi
    fi
  done
  [ "$any" = 1 ] && REMOVED+=("cursor") || { SKIPPED+=("cursor"); note "  nothing to remove"; }
}

# ── Codex ───────────────────────────────────────────────────────────────────
remove_codex() {
  only_filter "codex" || return 0
  local dir="$HOME_DIR/.codex"
  [ -d "$dir" ] || return 0
  say "→ Codex CLI"
  local any=0 s
  for s in "$dir/skills/clock" "$dir/skills/system-stats"; do
    if [ -d "$s" ]; then
      any=1
      if [ "$DRY" = 1 ]; then note "  [dry-run] rm -rf $s"
      else rm -rf "$s"; note "  removed: $s"; fi
    fi
  done
  local md="$dir/AGENTS.md"
  if [ -f "$md" ] && grep -q '<!-- omni-skills:begin -->' "$md"; then
    any=1
    if [ "$DRY" = 1 ]; then
      note "  [dry-run] strip omni-skills block from $md"
    else
      local tmp="$md.tmp"
      awk '
        BEGIN {skip=0}
        /<!-- omni-skills:begin -->/ {skip=1; next}
        /<!-- omni-skills:end -->/ {skip=0; next}
        !skip {print}
      ' "$md" > "$tmp" && mv "$tmp" "$md"
      note "  stripped block from: $md"
    fi
  fi
  [ "$any" = 1 ] && REMOVED+=("codex") || { SKIPPED+=("codex"); note "  nothing to remove"; }
}

# ── Generic ─────────────────────────────────────────────────────────────────
remove_generic() {
  only_filter "generic" || return 0
  local dir="$HOME_DIR/.agents"
  [ -d "$dir" ] || return 0
  say "→ Generic .agents"
  local any=0 s
  for s in "$dir/skills/clock" "$dir/skills/system-stats"; do
    if [ -d "$s" ]; then
      any=1
      if [ "$DRY" = 1 ]; then note "  [dry-run] rm -rf $s"
      else rm -rf "$s"; note "  removed: $s"; fi
    fi
  done
  [ "$any" = 1 ] && REMOVED+=("generic") || { SKIPPED+=("generic"); note "  nothing to remove"; }
}

remove_claude
remove_gemini
remove_cursor
remove_codex
remove_generic

echo "────────────────────────────────────"
[ ${#REMOVED[@]} -gt 0 ] && say  "✓ Removed: ${REMOVED[*]}"
[ ${#SKIPPED[@]} -gt 0 ] && note "⊘ Nothing to remove: ${SKIPPED[*]}"
[ ${#FAILED[@]}  -gt 0 ] && err  "✗ Failed: ${FAILED[*]}"
if [ ${#REMOVED[@]} -eq 0 ] && [ ${#SKIPPED[@]} -eq 0 ] && [ ${#FAILED[@]} -eq 0 ]; then
  warn "No supported agents detected."
fi
echo "────────────────────────────────────"

if [ "${#FAILED[@]}" -gt 0 ]; then exit 1; fi
exit 0
