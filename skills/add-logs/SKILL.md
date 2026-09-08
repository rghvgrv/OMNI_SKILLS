---
name: add-logs
description: >
  Adds logging statements to source code. Detects the programming language from
  file extension and existing imports, picks the project's already-used logger,
  and inserts logs only at points that carry diagnostic value (error paths,
  external I/O, branch outcomes, state changes). Use when user says "/addLogs",
  "add logs", "add logging", "instrument this file", "add debug statements",
  or asks why a function is hard to debug without output.
---

## When to use

Trigger on: `/addLogs`, `/add-logs`, "add logs", "add logging to X", "instrument
this", "add debug output".

Scope defaults to **files changed in the working tree** (`git diff --name-only HEAD`).
If the tree is clean, ask which file/dir. If the user names a target, use it.

Do **not** use for: writing a logging framework, configuring log sinks/rotation,
or converting an existing logger to another one. Those are refactors, not this.

## Step 1 — Detect language

Map by extension:

| Ext | Language |
|---|---|
| `.py` | Python |
| `.js` `.mjs` `.cjs` `.jsx` | JavaScript |
| `.ts` `.tsx` | TypeScript |
| `.java` | Java |
| `.kt` | Kotlin |
| `.go` | Go |
| `.rs` | Rust |
| `.rb` | Ruby |
| `.php` | PHP |
| `.cs` | C# |
| `.c` `.h` `.cpp` `.hpp` | C/C++ |
| `.swift` | Swift |
| `.sh` `.bash` | Shell |
| `.sql` | SQL — skip, no logging |

Ambiguous or no extension: read the shebang, then the syntax.

## Step 2 — Detect the logger already in use

**Never introduce a new logging dependency.** Grep the file first, then its
siblings, then the project root config, in that order. First hit wins.

```
grep -rn "logger\|logging\|log\.\|Log\.\|console\.\|slog\|zap\|winston\|pino\|log4j\|serilog\|tracing" <dir>
```

Fallbacks when a project has no logger at all — stdlib only:

| Language | Fallback |
|---|---|
| Python | `import logging` + `logger = logging.getLogger(__name__)` |
| JS/TS | `console.debug` / `console.error` |
| Java | `java.util.logging.Logger` (or SLF4J if already on the classpath) |
| Kotlin | SLF4J if present, else `println` in scripts only |
| Go | `log/slog` |
| Rust | `log` crate if present, else `eprintln!` |
| Ruby | `Logger.new($stdout)` |
| PHP | `error_log()` (PSR-3 logger if one is injected) |
| C# | `ILogger<T>` if DI present, else `System.Diagnostics.Debug` |
| C/C++ | `fprintf(stderr, ...)` |
| Swift | `os.Logger` |
| Shell | `echo "..." >&2` |

Match the surrounding file's style: if it already uses f-strings, structured
key-value fields, or a `[Module]` prefix, copy that convention exactly.

## Step 3 — Where to log

Insert **only** at these points:

1. **Catch/except/rescue/`if err != nil`** — always. Log the error object plus
   the inputs needed to reproduce. This is the highest-value log in any file.
2. **Function entry for non-trivial functions** — DEBUG level, with arguments.
   Non-trivial = branching, loops, I/O, or >15 lines. Skip getters, setters,
   one-line pass-throughs, `__init__`/constructors that only assign.
3. **External boundaries** — HTTP calls, DB queries, file I/O, queue
   publish/consume, subprocess spawn. Log before (target + params) and after
   (status + duration/row count).
4. **Branch outcomes that are not obvious from the return value** — early
   returns, guard clauses, cache hit/miss, retry attempts, fallback taken.
5. **State mutations that outlive the function** — writes to shared state,
   cache invalidation, config reload.

Level guide: `ERROR` unrecoverable, `WARN` recovered/degraded/retried,
`INFO` business-meaningful events, `DEBUG` flow and arguments.

## Step 4 — Where NOT to log

- **Secrets and PII.** Never log passwords, tokens, API keys, auth headers,
  cookies, full card numbers, or raw request bodies that may hold them.
  Redact (`token=<redacted>`) or log only length/prefix.
- Inside hot loops — log once before with the iteration count, once after with
  the result. If per-iteration detail is genuinely needed, gate it.
- Trivial accessors, pure one-line helpers, generated code, vendored code.
- Between every consecutive statement. Line-by-line logging is noise, not
  observability.
- Anything that changes control flow, evaluation order, or has side effects
  inside the log argument (no `log(next(it))`, no `log(pop())`).

Budget: aim for **≤1 log per 15 lines** of the file. If a file needs more than
that to be understandable, say so and stop — it needs splitting, not logging.

## Step 5 — Apply

1. Add the import/logger init once at the top if missing.
2. Insert statements. Preserve indentation, quote style, and line endings.
3. Do not reformat, reorder, or otherwise touch surrounding lines.
4. Verify the file still parses:
   `python -m py_compile`, `node --check`, `go build ./...`, `tsc --noEmit`,
   `cargo check`, `ruby -c`, `php -l`, `bash -n` — whichever fits.
5. Report: files touched, log count per file, logger used.

## Output format

```
Language: <detected>
Logger:   <existing logger found | stdlib fallback>
Files:
  path/to/file.py  +6 logs (1 error, 2 entry, 3 boundary)
Syntax check: pass
```

## Notes

- Existing logs stay. Never delete or rewrite a log the author already wrote.
- If a file already meets the budget, report "already instrumented" and skip it.
- Multi-language changesets: process each file with its own language rules.
