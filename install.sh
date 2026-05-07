#!/usr/bin/env bash
# OMNI_SKILLS — multi-agent installer (POSIX bash).
#
# One line (macOS / Linux / Git Bash):
#   curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.sh | bash
#
# Detects which AI coding agents are on the machine and installs OMNI_SKILLS
# globally for each one via that agent's native plugin/extension manager.
# Falls back to file-copy install for agents without a plugin manager.

set -euo pipefail

REPO="rghvgrv/OMNI_SKILLS"
REPO_URL="https://github.com/$REPO"
ASSETS_REF="${OMNI_REF:-main}"

# ── Flags ────────────────────────────────────────────────────────────────────
DRY=0
LIST_ONLY=0
NO_COLOR=0
FORCE=0
ONLY=()
WOULD_INSTALL=()
INSTALLED=()
SKIPPED=()
FAILED=()

print_help() {
  cat <<'EOF'
OMNI_SKILLS installer

USAGE
  install.sh [flags]
  curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.sh | bash

FLAGS
  --dry-run         Print what would run, do nothing.
  --only <agent>    Install only for the named agent. Repeatable.
  --agent <agent>   Alias for --only (single agent).
  --force, -f       Overwrite existing copies (file-copy agents only).
  --list            Print supported agents and exit.
  --no-color        Disable ANSI color codes.
  -h, --help        Show this help and exit.

ENVIRONMENT
  OMNI_REF          Git ref used for fallback installs. Default: main

SUPPORTED AGENTS
  Native plugin manager (global):
    claude       Claude Code         claude plugin marketplace add + install
    gemini       Gemini CLI          gemini extensions install
  File-copy fallback (per-user):
    cursor       Cursor              ~/.cursor/rules/<skill>.mdc
    codex        Codex CLI           ~/.codex/skills/<skill>/
    generic      Generic .agents     ~/.agents/skills/<skill>/

EXAMPLES
  install.sh                        # auto-detect all agents
  install.sh --only claude
  install.sh --only claude --only gemini
  install.sh --dry-run
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY=1 ;;
    --list)      LIST_ONLY=1 ;;
    --no-color)  NO_COLOR=1 ;;
    --force|-f)  FORCE=1 ;;
    --only|--agent)
      shift
      [ $# -eq 0 ] && { echo "error: --only requires an argument" >&2; exit 2; }
      ONLY+=("$1") ;;
    --agent=*) ONLY+=("${1#*=}") ;;
    -h|--help)   print_help; exit 0 ;;
    *) echo "error: unknown flag: $1" >&2; echo "run 'install.sh --help' for usage" >&2; exit 2 ;;
  esac
  shift
done

if [ "$LIST_ONLY" = 1 ]; then print_help; exit 0; fi

# ── Color ────────────────────────────────────────────────────────────────────
if [ ! -t 1 ]; then NO_COLOR=1; fi
c_green=""; c_yellow=""; c_red=""; c_dim=""; c_reset=""
if [ "$NO_COLOR" = 0 ]; then
  c_green=$'\033[0;32m'
  c_yellow=$'\033[0;33m'
  c_red=$'\033[0;31m'
  c_dim=$'\033[2m'
  c_reset=$'\033[0m'
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

# ── Native: Claude Code ──────────────────────────────────────────────────────
install_claude() {
  only_filter "claude" || return 0
  command -v claude >/dev/null 2>&1 || return 0
  say "→ Claude Code detected"
  if [ "$DRY" = 1 ]; then
    note "  [dry-run] claude plugin marketplace add $REPO"
    note "  [dry-run] claude plugin install omni-skills@omni-skills"
    WOULD_INSTALL+=("claude")
    echo
    return 0
  fi
  if claude plugin marketplace add "$REPO" && claude plugin install "omni-skills@omni-skills"; then
    INSTALLED+=("claude")
  else
    FAILED+=("claude")
    err "  claude plugin install failed"
  fi
  echo
}

# ── Native: Gemini CLI ───────────────────────────────────────────────────────
install_gemini() {
  only_filter "gemini" || return 0
  command -v gemini >/dev/null 2>&1 || return 0
  say "→ Gemini CLI detected"

  local integrity="$HOME/.gemini/extension_integrity.json"
  if [ -f "$integrity" ] && command -v python3 >/dev/null 2>&1 \
       && ! python3 -m json.tool "$integrity" >/dev/null 2>&1; then
    note "  clearing corrupted Gemini integrity store"
    [ "$DRY" = 0 ] && rm -f "$integrity"
  fi

  if [ "$DRY" = 1 ]; then
    note "  [dry-run] gemini extensions install --consent $REPO_URL"
    WOULD_INSTALL+=("gemini")
    echo
    return 0
  fi

  local out
  if out=$(gemini extensions install --consent "$REPO_URL" 2>&1); then
    echo "$out"
    INSTALLED+=("gemini")
  else
    echo "$out"
    if echo "$out" | grep -qi "already installed"; then
      note "  Gemini extension already installed; continuing"
      INSTALLED+=("gemini")
    else
      FAILED+=("gemini")
      err "  gemini extensions install failed"
    fi
  fi
  echo
}

# ── File-copy fallback for cursor / codex / generic ─────────────────────────
HOME_DIR="${HOME:-${USERPROFILE:-}}"
CURSOR_DIR="$HOME_DIR/.cursor"
CODEX_DIR="$HOME_DIR/.codex"
GENERIC_DIR="$HOME_DIR/.agents"

# Resolve repo root: directory containing this script if invoked locally,
# otherwise download to a temp dir.
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" 2>/dev/null && pwd || true)"
REPO_ROOT=""
TEMP_REPO=0

ensure_repo_root() {
  [ -n "$REPO_ROOT" ] && return 0
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install.sh" ] && [ -d "$SCRIPT_DIR/skills" ]; then
    REPO_ROOT="$SCRIPT_DIR"
    return 0
  fi
  REPO_ROOT="$(mktemp -d -t omni-skills-XXXXXX)"
  TEMP_REPO=1
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 --branch "$ASSETS_REF" "$REPO_URL.git" "$REPO_ROOT" >/dev/null 2>&1 \
      || { err "  git clone failed"; return 1; }
  elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    local tar_url="https://codeload.github.com/$REPO/tar.gz/refs/heads/$ASSETS_REF"
    curl -fsSL "$tar_url" | tar -xz -C "$REPO_ROOT" --strip-components=1 \
      || { err "  tarball fetch failed"; return 1; }
  else
    err "  need git or (curl + tar) for fallback install"
    return 1
  fi
}

cleanup_repo_root() {
  [ "$TEMP_REPO" = 1 ] && [ -n "$REPO_ROOT" ] && rm -rf "$REPO_ROOT"
}
trap cleanup_repo_root EXIT

SKILL_NAMES="clock system-stats"

copy_skill_tree() {
  local dest="$1"
  mkdir -p "$dest"
  local s
  for s in $SKILL_NAMES; do
    if [ -d "$dest/$s" ] && [ "$FORCE" -eq 0 ]; then
      note "  skip $s (exists; --force to overwrite)"
      continue
    fi
    rm -rf "$dest/$s"
    mkdir -p "$dest/$s"
    cp -R "$REPO_ROOT/skills/$s/." "$dest/$s/"
    note "  installed: $dest/$s"
  done
}

write_cursor_rule() {
  local name="$1" mdc="$2"
  local script
  script="$(ls "$REPO_ROOT/skills/$name"/*.sh 2>/dev/null | head -n1)"
  script="$(basename "$script")"
  local desc
  desc="$(awk -F'> ' '/^description:/ {sub(/^description:[[:space:]]*>?[[:space:]]*/,"",$0); print; exit}' "$REPO_ROOT/skills/$name/skill.md" 2>/dev/null)"
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

append_agents_block() {
  local md="$1"
  local begin="<!-- omni-skills:begin -->"
  local end="<!-- omni-skills:end -->"
  [ -f "$md" ] || : > "$md"
  if grep -q "$begin" "$md"; then
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
    local s
    for s in $SKILL_NAMES; do
      printf -- '- **%s** — see `skills/%s/skill.md` (run `./skills/%s/*.sh`)\n' "$s" "$s" "$s"
    done
    printf '\n%s\n' "$end"
  } >> "$md"
}

install_cursor() {
  only_filter "cursor" || return 0
  [ -d "$CURSOR_DIR" ] || return 0
  say "→ Cursor detected: $CURSOR_DIR"
  if [ "$DRY" = 1 ]; then
    note "  [dry-run] write rules to $CURSOR_DIR/rules/"
    WOULD_INSTALL+=("cursor"); echo; return 0
  fi
  ensure_repo_root || { FAILED+=("cursor"); echo; return 0; }
  mkdir -p "$CURSOR_DIR/rules"
  local s target
  for s in $SKILL_NAMES; do
    target="$CURSOR_DIR/rules/$s.mdc"
    if [ -f "$target" ] && [ "$FORCE" -eq 0 ]; then
      note "  skip $s.mdc (exists; --force to overwrite)"
      continue
    fi
    write_cursor_rule "$s" "$target"
    note "  installed: $target"
  done
  INSTALLED+=("cursor")
  echo
}

install_codex() {
  only_filter "codex" || return 0
  [ -d "$CODEX_DIR" ] || return 0
  say "→ Codex CLI detected: $CODEX_DIR"
  if [ "$DRY" = 1 ]; then
    note "  [dry-run] copy skills + write AGENTS.md block in $CODEX_DIR"
    WOULD_INSTALL+=("codex"); echo; return 0
  fi
  ensure_repo_root || { FAILED+=("codex"); echo; return 0; }
  copy_skill_tree "$CODEX_DIR/skills"
  append_agents_block "$CODEX_DIR/AGENTS.md"
  note "  installed: $CODEX_DIR/AGENTS.md (omni-skills block)"
  INSTALLED+=("codex")
  echo
}

install_generic() {
  only_filter "generic" || return 0
  [ -d "$GENERIC_DIR" ] || return 0
  say "→ Generic .agents detected: $GENERIC_DIR"
  if [ "$DRY" = 1 ]; then
    note "  [dry-run] copy skills to $GENERIC_DIR/skills/"
    WOULD_INSTALL+=("generic"); echo; return 0
  fi
  ensure_repo_root || { FAILED+=("generic"); echo; return 0; }
  copy_skill_tree "$GENERIC_DIR/skills"
  INSTALLED+=("generic")
  echo
}

# ── Run installs ─────────────────────────────────────────────────────────────
install_claude
install_gemini
install_cursor
install_codex
install_generic

# ── Summary ──────────────────────────────────────────────────────────────────
echo "────────────────────────────────────"
[ ${#INSTALLED[@]}     -gt 0 ] && say  "✓ Installed: ${INSTALLED[*]}"
[ ${#WOULD_INSTALL[@]} -gt 0 ] && note "~ Would install (dry-run): ${WOULD_INSTALL[*]}"
[ ${#SKIPPED[@]}       -gt 0 ] && warn "⊘ Skipped (missing dep): ${SKIPPED[*]}"
[ ${#FAILED[@]}        -gt 0 ] && err  "✗ Failed: ${FAILED[*]}"

if [ ${#INSTALLED[@]} -eq 0 ] && [ ${#FAILED[@]} -eq 0 ] && [ ${#SKIPPED[@]} -eq 0 ] && [ ${#WOULD_INSTALL[@]} -eq 0 ]; then
  if [ "${#ONLY[@]}" -gt 0 ]; then
    warn "None of the specified agents were detected on this machine."
  else
    warn "No supported agents detected."
    note "Install Claude Code, Gemini CLI, Cursor, or Codex first."
  fi
fi
echo "────────────────────────────────────"

[ "${#FAILED[@]}" -gt 0 ] && exit 1
exit 0
