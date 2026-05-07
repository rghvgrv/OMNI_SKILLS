#!/usr/bin/env bash
# OMNI_SKILLS — one-shot uninstaller (POSIX bash).
#
# One line:
#   curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/uninstall.sh | bash
#
# Removes OMNI_SKILLS from every detected agent. Idempotent.

set -euo pipefail

REPO="rghvgrv/OMNI_SKILLS"

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
  claude  gemini  codex  copilot  antigravity
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
    note "  [dry-run] claude plugin marketplace remove $REPO"
    return 0
  fi
  local ok=1
  claude plugin uninstall "omni-skills@omni-skills" || ok=0
  claude plugin marketplace remove "$REPO" || true
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

# ── Generic: npx skills remove ──────────────────────────────────────────────
remove_via_skills() {
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
  fi
  [ "$detected" = 0 ] && return 0

  say "→ $label"
  if ! command -v node >/dev/null 2>&1; then
    warn "  node/npx not found — skipping"
    SKIPPED+=("$id")
    return 0
  fi

  if [ "$DRY" = 1 ]; then
    note "  [dry-run] npx -y skills remove $REPO -a $profile --yes --global"
    return 0
  fi

  if npx -y skills remove "$REPO" -a "$profile" --yes --global 2>&1; then
    REMOVED+=("$id")
  else
    SKIPPED+=("$id")
    note "  npx skills remove returned non-zero — likely already absent"
  fi
}

remove_claude
remove_gemini

remove_via_skills "codex"       "Codex CLI + GUI"              "cmd:codex"                "codex"
remove_via_skills "copilot"     "GitHub Copilot CLI + VS Code" "cmd:gh"                   "github-copilot"
remove_via_skills "antigravity" "Gemini GUI (Antigravity)"     "dir:$HOME_DIR/.antigravity" "antigravity"

# Direct cleanup of ~/.agents/skills/<skill>
for s in clock system-stats; do
  p="$HOME_DIR/.agents/skills/$s"
  if [ -d "$p" ]; then
    if [ "$DRY" = 1 ]; then note "  [dry-run] rm -rf $p"
    else rm -rf "$p"; note "  removed: $p"; fi
  fi
done

echo "────────────────────────────────────"
[ ${#REMOVED[@]} -gt 0 ] && say  "✓ Removed: ${REMOVED[*]}"
[ ${#SKIPPED[@]} -gt 0 ] && note "⊘ Nothing to remove / not installed: ${SKIPPED[*]}"
[ ${#FAILED[@]}  -gt 0 ] && err  "✗ Failed: ${FAILED[*]}"
if [ ${#REMOVED[@]} -eq 0 ] && [ ${#SKIPPED[@]} -eq 0 ] && [ ${#FAILED[@]} -eq 0 ]; then
  warn "No supported agents detected."
fi
echo "────────────────────────────────────"

if [ "${#FAILED[@]}" -gt 0 ]; then exit 1; fi
exit 0
