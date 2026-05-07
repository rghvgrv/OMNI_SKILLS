# OMNI_SKILLS

> Universal AI agent skill toolkit — two skills, one installer, every major agent.

## Skills

| Skill | What it does | Script |
|---|---|---|
| **clock** | Current date, time, timezone, Unix epoch | `skills/clock/clock.sh` |
| **system-stats** | OS, hostname, CPU, memory, disk, uptime | `skills/system-stats/stats.sh` |

Pure POSIX bash. Linux, macOS, Windows (Git Bash / MSYS / Cygwin). On Windows, `system-stats` falls back to PowerShell for CPU / memory / uptime.

## Quick install

**macOS / Linux / Git Bash:**

```bash
curl -fsSL https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/rghvgrv/OMNI_SKILLS/main/install.ps1 | iex
```

The installer detects every AI agent on the machine and registers the skills with each. Re-runs are idempotent. Agents that aren't installed are skipped silently.

### From a clone

```bash
git clone https://github.com/rghvgrv/OMNI_SKILLS
cd OMNI_SKILLS
bash install.sh
```

### Flags

```bash
bash install.sh --force            # overwrite existing skill copies
bash install.sh --agent claude     # install only to one agent
bash install.sh --agent gemini
bash install.sh --agent cursor
bash install.sh --agent codex
bash install.sh --agent generic
```

PowerShell mirror: `install.ps1 -Force` / `install.ps1 -Agent claude`.

## Supported agents

| Agent | Detection | Where files land |
|---|---|---|
| Claude Code | `~/.claude/` exists | `~/.claude/skills/<name>/` + SessionStart hook in `settings.json` |
| Gemini CLI | `~/.gemini/` exists | `~/.gemini/extensions/<name>/` + `gemini-extension.json` |
| Cursor | `~/.cursor/` exists | `~/.cursor/rules/<name>.mdc` |
| Codex CLI | `~/.codex/` exists | `~/.codex/skills/<name>/` + block in `~/.codex/AGENTS.md` |
| Generic | `~/.agents/` exists | `~/.agents/skills/<name>/` |

## Requirements

- `bash` (Git Bash on Windows is fine — `install.ps1` finds it for you)
- `node` — only needed to merge the Claude Code SessionStart hook into `settings.json`. Skipped with a warning if absent.

## Use

After install, the host agent loads the skill on session start. You can also run the scripts directly to see output:

```bash
./skills/clock/clock.sh
./skills/system-stats/stats.sh
```

Sample output:

```
Current Date: 2026-05-07
Current Time: 14:45:01
Timezone: IST
Unix Epoch: 1778153701
```

```
OS: Microsoft Windows 11 Home Single Language
Hostname: DESKTOP-CTTEFBC
CPU: Intel(R) Core(TM) i5-8300H CPU @ 2.30GHz (8 cores)
Memory: 9824 MB used / 16228 MB total
Disk: 142G used / 232G total (61% used)
Uptime: 0d 0h 41m
```

## Test

Tests use `bats-core`, fetched on first run by `tests/bootstrap.sh`.

```bash
bash tests/bootstrap.sh
tests/.bin/bats-core/bin/bats tests/
```

Or one-liner:

```bash
bash tests/bootstrap.sh && tests/.bin/bats-core/bin/bats tests/
```

Expected: 33 tests, all passing.

## Uninstall

```bash
rm -rf ~/.claude/skills/clock ~/.claude/skills/system-stats
rm -rf ~/.gemini/extensions/clock ~/.gemini/extensions/system-stats
rm -f  ~/.cursor/rules/clock.mdc ~/.cursor/rules/system-stats.mdc
rm -rf ~/.codex/skills/clock ~/.codex/skills/system-stats
```

Also remove:
- The `<!-- omni-skills:begin -->` … `<!-- omni-skills:end -->` block from `~/.codex/AGENTS.md`
- The SessionStart hook entry containing `omni-skills` from `~/.claude/settings.json`

## Repo layout

```
.
├── install.sh                    # universal bash installer
├── install.ps1                   # Windows wrapper (delegates to install.sh)
├── merge-settings.js             # idempotent JSON merge for Claude settings.json
├── gemini-extension.json         # Gemini CLI extension manifest
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── clock/
│   │   ├── skill.md
│   │   └── clock.sh
│   └── system-stats/
│       ├── skill.md
│       └── stats.sh
└── tests/
    ├── bootstrap.sh
    ├── clock.bats
    ├── stats.bats
    └── install.bats
```

## To check all the skills available at global level in your system, you can run the following command in your terminal:

```bash
npx -y skills list --global
```

## License

MIT — see `LICENSE`.
