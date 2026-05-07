# OMNI_SKILLS

> Universal AI agent skill toolkit — markdown-only skills, multi-agent installer, every major coding agent.

## Skills

| Skill | What it does |
|---|---|
| **clock** | Current date, time, timezone, Unix epoch |
| **system-stats** | OS, hostname, CPU, memory, disk, uptime |
| **min-token** | Ultra-compressed reply mode — drops filler, keeps signal |

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

- **Claude Code** (plugin)
```bash
claude plugin install rghvgrv/OMNI_SKILLS 
```
- **GitHub Copilot** (npx-skills)
```bash
npx -y skills add rghvgrv/OMNI_SKILLS -a github-copilot --global
```
- **VS Code (Copilot)** (npx-skills) — detected via `code` CLI
```bash
npx -y skills add rghvgrv/OMNI_SKILLS -a github-copilot --global
```
Or via installer:
```powershell
.\install.ps1 -Only vscode
```
```bash
bash install.sh --only vscode
```
- **Gemini CLI** (extension)
```bash
gemini extensions install rghvgrv/OMNI_SKILLS
```
- **Antigravity** (npx-skills)
```bash
npx -y skills add rghvgrv/OMNI_SKILLS -a antigravity --global
```
- **Codex** (npx-skills)
```bash
npx -y skills add rghvgrv/OMNI_SKILLS -a codex --global
```


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
claude plugin marketplace remove rghvgrv/OMNI_SKILLS
gemini extensions uninstall omni-skills
```

**npx-skills agents** (note: `skills remove` matches by **skill name**, not repo):
```bash
npx -y skills remove clock        -a codex --yes --global
npx -y skills remove system-stats -a codex --yes --global
npx -y skills remove min-token    -a codex --yes --global
# repeat for -a github-copilot, -a antigravity if installed
```

Or just nuke the global skill dirs:
```bash
rm -rf ~/.agents/skills/clock ~/.agents/skills/system-stats ~/.agents/skills/min-token
```

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
    ├── system-stats/
    │   └── SKILL.md
    └── min-token/
        └── SKILL.md
```

## To check all the skills available at global level in your system, you can run the following command in your terminal:

```bash
npx -y skills list --global
```

## License

MIT — see `LICENSE`.
