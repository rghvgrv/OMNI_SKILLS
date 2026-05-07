---
name: system-stats
description: > Reports local CPU, memory, disk, OS, hostname, uptime.
usage: Run ./stats.sh
---

### Intent
Provides AI agent with snapshot of host system resources. Use when user asks:
- "How much memory am I using?"
- "What's the CPU on this box?"
- "Show disk usage."
- "What OS is this?"

### Execution
Run from repo root:
`./skills/system-stats/stats.sh`

Cross-OS: Linux, macOS, Windows (Git Bash / MSYS / Cygwin). Falls back to PowerShell on Windows when wmic absent.

### Output Handling
Multi-line. Each line `Key: Value`.

**Example Output:**
> OS: Microsoft Windows 11 Home Single Language
> Hostname: DESKTOP-CTTEFBC
> CPU: Intel Core i5-8300H @ 2.30GHz (8 cores)
> Memory: 9824 MB used / 16228 MB total
> Disk: 142G used / 232G total (61% used)
> Uptime: 0d 0h 41m

### Response Guidelines
- Convert raw MB to GB (1 dp) when reporting to user.
- Highlight values above thresholds: memory > 90%, disk > 90%.
- If a field reads `unknown`, note tool limitation rather than guessing.

### Negative cases
- Unsupported OS → exit 2 with stderr message.
- Set `OMNI_FORCE_OS=plan9` to test failure path.
