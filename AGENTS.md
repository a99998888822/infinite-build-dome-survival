# AGENTS.md

## Encoding Rules for Codex on Windows

This project uses UTF-8 for source code, JSON data, Markdown design docs, Godot scenes, and Godot scripts.

When working in this repository on Windows:

- Treat every text file as UTF-8. Prefer UTF-8 without BOM for new files unless the existing file already uses a different encoding.
- Do not rely on the active PowerShell or console code page for reading or writing non-ASCII text.
- Prefer `apply_patch` for focused edits. Keep patches small and avoid rewriting entire Chinese documents unless necessary.
- When using PowerShell to read text, pass `-Encoding UTF8`, for example `Get-Content -Encoding UTF8`.
- When using PowerShell to write text, pass `-Encoding UTF8` explicitly and verify the result before continuing.
- For bulk text transforms, prefer Python with explicit `encoding="utf-8"` on every `open()`, `Path.read_text()`, and `Path.write_text()` call.
- Avoid passing Chinese text through fragile shell here-strings, redirected `echo`, or default `Out-File` calls. These can produce question-mark mojibake on some Windows shells.
- Do not put Chinese literals directly inside inline scripts passed through PowerShell, including `@' ... '@ | python -`, `python -c "..."`, `node -e "..."`, or similar command strings. Even when the target file is opened as UTF-8, the script source itself may already have been decoded through the console code page and can silently turn Chinese literals into question marks.
- If a command must generate or compare non-ASCII text, use one of these safer approaches:
  - Prefer `apply_patch` for small edits that include Chinese text.
  - Reuse already-correct text read from existing UTF-8 files instead of retyping Chinese literals in the command.
  - Use ASCII-only inline scripts with Unicode escapes such as `"\u672a\u5b58\u5728"` for Chinese constants.
  - Write a temporary UTF-8 script file with a tool that preserves bytes, then execute that file, instead of piping script text through PowerShell.
- After editing Chinese text, JSON strings, or Godot text resources, check for accidental replacement characters or mojibake before finalizing.
- Do not trust terminal-rendered Chinese alone as proof of correctness. PowerShell output may render mojibake while the file is still valid, or render replacement-looking text after the file has already been damaged. Use byte/escape-based checks for verification.

Recommended quick checks:

```powershell
rg '\x{FFFD}|\?{4,}' . --glob '!AGENTS.md'
git diff --check
```

Safer Python verification pattern:

```powershell
@'
from pathlib import Path
text = Path("docs/asset/asset_checklist_summary.md").read_text(encoding="utf-8", errors="replace")
bad_question_run = "?" * 4
for line_no, line in enumerate(text.splitlines(), 1):
    if "\ufffd" in line or bad_question_run in line:
        print(line_no, line.encode("unicode_escape").decode("ascii"))
'@ | python -
```

When writing automation scripts from PowerShell, keep the script source ASCII-only whenever possible. Build Chinese strings using Unicode escapes or copy them from previously decoded UTF-8 file content; never manually retype long Chinese rows inside a PowerShell here-string.

PowerShell Compatibility Notes:

- This environment may use Windows PowerShell 5.x, which does not support Bash-style heredocs such as `<<'PATCH'`. To invoke `apply_patch`, use a tool-native patch call when available; otherwise write the patch to a UTF-8 temporary file and pipe it with `Get-Content -Raw -Encoding UTF8 <file> | apply_patch`.
- Do not use Bash operators such as `||` or `&&` in PowerShell commands. Check `$LASTEXITCODE` or `$?` explicitly, for example: `$result = rg 'pattern' .; if ($LASTEXITCODE -ne 0) { 'NONE' }`.
- Do not assume `godot` or `godot4` is installed. Probe with `Get-Command godot -ErrorAction SilentlyContinue` and `Get-Command godot4 -ErrorAction SilentlyContinue`; report `GODOT_NOT_FOUND` instead of treating the missing executable as a project failure.
- Avoid PowerShell here-strings for commands containing Chinese or other non-ASCII literals, even when the destination file is UTF-8. Prefer a small `apply_patch` edit, an ASCII-only script with `\uXXXX` escapes, or a temporary script written with explicit UTF-8 encoding.
- When a multiline patch fails with a PowerShell parser error, do not retry the same `<<...` syntax. Switch immediately to `@' ... '@ | apply_patch` or a UTF-8 temporary patch file, and keep the patch content separate from the command string.
- For verification commands that intentionally return a non-zero status, capture the result and normalize the status before running subsequent checks; do not chain them with Bash syntax.

Godot-specific notes:

- Keep `.gd`, `.tscn`, `.tres`, `.json`, and `.md` files UTF-8 encoded.
- Do not hand-create `.gd.uid` files unless Godot itself generated them or the project already follows that convention.
- Preserve existing line endings unless a formatter or project convention says otherwise.
