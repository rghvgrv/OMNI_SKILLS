#!/usr/bin/env bash
# OMNI_SKILLS — multi-agent installer (POSIX bash).
#
# One line (macOS / Linux / Git Bash):
#   curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.sh | bash
#
# Detects which AI coding agents are on the machine and installs OMNI_SKILLS
# globally for each via that agent's native plugin/extension manager, or via
# `npx skills add` for agents without one. No file copying.

set -euo pipefail

REPO="rghvgrv/OMNI_SKILLS"
REPO_URL="https://github.com/$REPO"

DRY=0
LIST_ONLY=0
NO_COLOR=0
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
  --list            Print supported agents and exit.
  --no-color        Disable ANSI color codes.
  -h, --help        Show this help and exit.

SUPPORTED AGENTS
  Native:
    claude       Claude Code CLI + App      claude plugin marketplace add + install
    gemini       Gemini CLI                 gemini extensions install
  Via npx skills add:
    codex        Codex CLI + GUI
    copilot      GitHub Copilot CLI + VS Code
    antigravity  Gemini GUI (Antigravity)

EXAMPLES
  install.sh                        # auto-detect all agents
  install.sh --only claude
  install.sh --only copilot --only codex
  install.sh --dry-run
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY=1 ;;
    --list)      LIST_ONLY=1 ;;
    --no-color)  NO_COLOR=1 ;;
    --only)
      shift
      [ $# -eq 0 ] && { echo "error: --only requires an argument" >&2; exit 2; }
      ONLY+=("$1") ;;
    -h|--help)   print_help; exit 0 ;;
    *) echo "error: unknown flag: $1" >&2; echo "run 'install.sh --help' for usage" >&2; exit 2 ;;
  esac
  shift
done

if [ "$LIST_ONLY" = 1 ]; then print_help; exit 0; fi

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

try() {
  if [ "$DRY" = 1 ]; then
    note "  [dry-run] $*"
    return 0
  fi
  "$@"
}

ensure_node() {
  command -v node >/dev/null 2>&1 && return 0
  warn "  node/npx not found — skipping (install Node.js from https://nodejs.org)"
  return 1
}

# ── Native: Claude Code ──────────────────────────────────────────────────────
install_claude() {
  only_filter "claude" || return 0
  command -v claude >/dev/null 2>&1 || return 0
  say "→ Claude Code detected"
  if try claude plugin marketplace add "$REPO" \
     && try claude plugin install "omni-skills@omni-skills"; then
    [ "$DRY" = 1 ] && WOULD_INSTALL+=("claude") || INSTALLED+=("claude")
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

# ── Generic: npx skills add ──────────────────────────────────────────────────
install_via_skills() {
  local id="$1"
  local label="$2"
  local detect="$3"
  local profile="$4"

  only_filter "$id" || return 0

  local detected=0
  if [[ "$detect" == cmd:* ]]; then
    command -v "${detect#cmd:}" >/dev/null 2>&1 && detected=1
  elif [[ "$detect" == dir:* ]]; then
    [ -d "${detect#dir:}" ] && detected=1
  else
    warn "  BUG: unknown detect_expr '$detect' for agent '$id'"
    return 0
  fi
  [ "$detected" = 0 ] && return 0

  say "→ $label detected"
  ensure_node || { SKIPPED+=("$id"); echo; return 0; }

  if try npx -y skills add "$REPO" -a "$profile" --yes --global; then
    [ "$DRY" = 1 ] && WOULD_INSTALL+=("$id") || INSTALLED+=("$id")
  else
    FAILED+=("$id")
    err "  npx skills add failed (profile: $profile)"
  fi
  echo
}

# ── Run installs ─────────────────────────────────────────────────────────────
install_claude
install_gemini

install_via_skills "codex"       "Codex CLI + GUI"              "cmd:codex"                "codex"
install_via_skills "copilot"     "GitHub Copilot CLI + VS Code" "cmd:gh"                   "github-copilot"
install_via_skills "antigravity" "Gemini GUI (Antigravity)"     "dir:$HOME/.antigravity"   "antigravity"

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
    note "Run 'install.sh --list' to see all supported agents."
  fi
fi
echo "────────────────────────────────────"

if [ "${#FAILED[@]}" -gt 0 ]; then
  exit 1
fi
exit 0
