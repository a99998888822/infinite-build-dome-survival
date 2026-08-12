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

Godot-specific notes:

- Keep `.gd`, `.tscn`, `.tres`, `.json`, and `.md` files UTF-8 encoded.
- Do not hand-create `.gd.uid` files unless Godot itself generated them or the project already follows that convention.
- Preserve existing line endings unless a formatter or project convention says otherwise.
