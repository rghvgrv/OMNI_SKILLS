---
name: clock
description: > Fetches the current system time, date, and timezone details.
usage: Run ./clock.sh
---

### Intent
This skill provides the AI agent with access to the host system's real-time clock. Use this tool when the user asks:
- "What time is it?"
- "What is today's date?"
- "Check if it is a leap year."

### Execution
The agent must execute the following script from the repository root:
`./skills/clock/clock.sh`

### Output Handling
The script returns a multi-line string containing the date, time, and Unix epoch.
**Example Output:**
> Current Date: 2026-05-07
> Current Time: 14:45:01
> Timezone: IST
> Unix Epoch: 1778153701

### Response Guidelines
- Convert the 24-hour output to the user's preferred format (e.g., 2:45 PM).
- If the user asks about a leap year, use the "Current Date" provided by this skill to perform the calculation.