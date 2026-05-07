# OMNI_SKILLS

> Universal AI agent skill toolkit — markdown-only skills, multi-agent installer, every major coding agent.

## Skills

| Skill | What it does |
|---|---|
| **clock** | Current date, time, timezone, Unix epoch |
| **system-stats** | OS, hostname, CPU, memory, disk, uptime |

Pure markdown instructions (`SKILL.md`). The host agent reads the skill and runs the appropriate per-OS shell commands itself — no bundled scripts. Linux, macOS, Windows (PowerShell or Git Bash).

## Quick install

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.ps1 | iex
```

**macOS / Linux / Git Bash:**

```bash
curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.sh | bash
```

The installer detects every AI agent on the machine and registers the skills via that agent's native plugin/extension manager (global install). For agents without a plugin manager, it falls back to a per-user file copy. Re-runs are idempotent. Agents that aren't installed are skipped silently.

### From a clone

```bash
git clone https://github.com/rghvgrv/OMNI_SKILLS
cd OMNI_SKILLS
bash install.sh
# or on Windows:
.\install.ps1
```

### Flags

```powershell
.\install.ps1 -DryRun                    # print what would run
.\install.ps1 -Only claude               # only Claude Code
.\install.ps1 -Only claude -Only gemini  # multiple
.\install.ps1 -Force                     # overwrite file-copy installs
.\install.ps1 -List                      # show supported agents
```

```bash
bash install.sh --dry-run
bash install.sh --only claude
bash install.sh --only claude --only gemini
bash install.sh --force
bash install.sh --list
```

## Supported agents

| Agent | Detection | Install method | Where files land |
|---|---|---|---|
| Claude Code | `claude` on PATH | `claude plugin marketplace add` + `claude plugin install` | `~/.claude/plugins/` (global, native) |
| Gemini CLI | `gemini` on PATH | `gemini extensions install --consent` | `~/.gemini/extensions/omni-skills/` (global, native) |
| Cursor | `~/.cursor/` exists | file copy | `~/.cursor/rules/<skill>.mdc` |
| Codex CLI | `~/.codex/` exists | file copy + AGENTS.md block | `~/.codex/skills/<skill>/` |
| Generic | `~/.agents/` exists | file copy | `~/.agents/skills/<skill>/` |

## Why markdown-only?

Earlier versions shipped `clock.sh` and `stats.sh` wrappers. That broke portability — Gemini extensions don't auto-run shell scripts. Now each `SKILL.md` lists the per-OS commands inline and the host agent invokes them via its own shell tool. Single source, every agent.

## Use

After install, the host agent loads the skill on session start and triggers it on natural-language requests. Manual probe via the agent's chat:

> "What time is it?" → agent runs the `clock` skill → returns 4-line report.
> "Show system stats." → agent runs the `system-stats` skill → returns 6-line report.

## Uninstall

### One-shot

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/uninstall.ps1 | iex
```

**macOS / Linux / Git Bash:**

```bash
curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/uninstall.sh | bash
```

Removes the plugin/extension from every detected agent and strips file-copy installs. Idempotent — safe to re-run. Skips agents that aren't installed.

### Manual

**Native plugin agents:**
```bash
claude plugin uninstall omni-skills@omni-skills
gemini extensions uninstall omni-skills
```

**File-copy agents:**
```bash
rm -f  ~/.cursor/rules/clock.mdc ~/.cursor/rules/system-stats.mdc
rm -rf ~/.codex/skills/clock ~/.codex/skills/system-stats
rm -rf ~/.agents/skills/clock ~/.agents/skills/system-stats
```

Also remove the `<!-- omni-skills:begin -->` … `<!-- omni-skills:end -->` block from `~/.codex/AGENTS.md` if present.

## Repo layout

```
.
├── install.sh                # universal bash installer
├── install.ps1               # Windows PowerShell installer
├── uninstall.sh              # universal bash uninstaller
├── uninstall.ps1             # Windows PowerShell uninstaller
├── gemini-extension.json     # Gemini CLI extension manifest
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
└── skills/
    ├── clock/
    │   └── SKILL.md
    └── system-stats/
        └── SKILL.md
```

## To check all the skills available at global level in your system, you can run the following command in your terminal:

```bash
npx -y skills list --global
```

## License

MIT — see `LICENSE`.
