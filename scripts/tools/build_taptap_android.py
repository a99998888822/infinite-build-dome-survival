"""Build the maintained TapTap Godot Android bridge with the project's wrapper.

Install Godot's Android build template before running this helper. Requires JDK
17 and Android SDK platform 36 / build-tools 36.1.0 (Gradle can install these).
An optional --godot then exports the configured Android Debug APK as well.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
from verify_taptap_apk import verify_apk


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java-home", type=Path, default=os.environ.get("JAVA_HOME"))
    parser.add_argument("--android-sdk", type=Path, default=os.environ.get("ANDROID_HOME"))
    parser.add_argument("--godot", type=Path)
    parser.add_argument("--apk", type=Path, default=Path("tmp/taptap_login_review/goblin-dungeon-taptap-compliance-v2-debug.apk"))
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    wrapper = project / "android/build/gradlew.bat"
    if not wrapper.is_file():
        parser.error("Install the matching Godot Android build template (Project > Install Android Build Template).")
    env = os.environ.copy()
    # A Gradle daemon can inherit the Windows Godot console launcher's pipe and
    # keep that launcher waiting after a successful export. Use single-run JVMs.
    env["GRADLE_OPTS"] = env.get("GRADLE_OPTS", "") + " -Dorg.gradle.daemon=false"
    env["JAVA_TOOL_OPTIONS"] = env.get("JAVA_TOOL_OPTIONS", "") + " -Dfile.encoding=UTF-8"
    if args.java_home:
        env["JAVA_HOME"] = str(args.java_home.resolve())
    if args.android_sdk:
        env["ANDROID_HOME"] = str(args.android_sdk.resolve())
    subprocess.run([str(wrapper), "-p", str(project / "addons/taptap/native"), "installBridge", "--console=plain"],
                   cwd=project, env=env, check=True)
    if args.godot:
        apk = (project / args.apk).resolve()
        apk.parent.mkdir(parents=True, exist_ok=True)
        engine = args.godot.resolve()
        # Run the engine directly: its console wrapper can retain inherited pipes.
        if engine.stem.endswith("_console"):
            direct_engine = engine.with_name(engine.name.replace("_console.exe", ".exe"))
            if direct_engine.is_file():
                engine = direct_engine
        subprocess.run([str(engine), "--headless", "--path", str(project),
                        "--export-debug", "Android", str(apk)], cwd=project, env=env,
                       check=True, timeout=600)
        report = verify_apk(apk)
        apk.with_suffix(".verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
