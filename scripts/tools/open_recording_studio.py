"""Open the recording studio manually, with progress isolated before autoloads."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


PROJECT = Path(__file__).resolve().parents[2]
SCENE = "res://scenes/debug/recording_studio.tscn"


def find_godot(explicit: str | None) -> Path:
    if explicit:
        candidate = Path(explicit).expanduser().resolve()
        if not candidate.is_file():
            raise FileNotFoundError(f"Godot not found: {candidate}")
        return candidate
    for name in ("godot", "godot4"):
        candidate = shutil.which(name)
        if candidate:
            return Path(candidate)
    if sys.platform == "win32":
        probe = r"""
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding
Get-CimInstance Win32_Process -Filter "Name LIKE '%Godot%'" -ErrorAction SilentlyContinue | ForEach-Object { $_.ExecutablePath }
$linkShell = New-Object -ComObject WScript.Shell
$roots = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory'), [Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('CommonPrograms'))
foreach ($root in $roots) {
    Get-ChildItem -LiteralPath $root -Filter '*Godot*.lnk' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $linkShell.CreateShortcut($_.FullName).TargetPath }
}
"""
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", probe], capture_output=True,
            encoding="utf-8", errors="replace", timeout=20,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        for line in result.stdout.splitlines():
            candidate = Path(line.strip())
            if candidate.is_file() and "godot" in candidate.name.lower():
                return candidate
        for root in (Path("D:/soft"), Path("C:/Program Files/Godot")):
            if root.is_dir():
                candidates = sorted(root.glob("*Godot*/*Godot*.exe")) + sorted(root.glob("*Godot*.exe"))
                for candidate in candidates:
                    if candidate.is_file() and "console" not in candidate.name.lower():
                        return candidate
    raise FileNotFoundError("GODOT_NOT_FOUND: use --godot C:/path/to/Godot.exe")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--print-command", action="store_true", help="Validate the launcher without opening a window")
    args = parser.parse_args()
    try:
        engine = find_godot(args.godot)
        command = [str(engine), "--path", str(PROJECT), "--scene", SCENE, "--", "--transient-session"]
        if args.print_command:
            print(json.dumps(command, ensure_ascii=True))
        else:
            subprocess.Popen(command, cwd=PROJECT, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        return 0
    except (OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
