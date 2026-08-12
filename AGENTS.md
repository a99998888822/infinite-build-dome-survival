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
- Avoid passing Chinese text through fragile shell here-strings, redirected `echo`, or default `Out-File` calls. These can produce mojibake such as `????` on some Windows shells.
- If a command must generate non-ASCII text, use a UTF-8-safe script file, escaped Unicode, or another method that avoids shell-codepage conversion.
- After editing Chinese text, JSON strings, or Godot text resources, check for accidental replacement characters or mojibake before finalizing.

Recommended quick checks:

```powershell
rg "\uFFFD|����|\?\?\?\?" .
git diff --check
```

Godot-specific notes:

- Keep `.gd`, `.tscn`, `.tres`, `.json`, and `.md` files UTF-8 encoded.
- Do not hand-create `.gd.uid` files unless Godot itself generated them or the project already follows that convention.
- Preserve existing line endings unless a formatter or project convention says otherwise.
