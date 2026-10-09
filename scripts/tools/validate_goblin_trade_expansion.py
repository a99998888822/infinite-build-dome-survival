"""Run isolated headless regressions for the goblin trade expansion."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SCENES = [
    "goblin_trade_expansion_test", "goblin_trade_test", "goblin_trade_cancellation_test",
    "goblin_loan_test", "finance_preparation_test", "humanity_economy_test",
    "principal_relic_test", "wave_challenge_test", "interest_arrival_test",
    "finance_scene_regression_test", "localization_test",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "artifacts/previews/goblin_trade_expansion_20261008")
    parser.add_argument("--scenes", nargs="*", default=SCENES)
    parser.add_argument("--review-logs", action="store_true", help="Recheck recorded results without rerunning Godot")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    summary_path = args.output / "headless_verification.json"
    previous = {entry["scene"]: entry for entry in json.loads(summary_path.read_text(encoding="utf-8"))} if args.review_logs else {}

    def run(scene):
        log = Path(previous[scene]["log"]) if args.review_logs and scene in previous else args.output / (scene + ".log")
        command = [args.godot, "--headless", "--path", str(ROOT), "--scene",
                   "res://scenes/tests/" + scene + ".tscn", "--", "--transient-session"]
        try:
            if args.review_logs:
                exit_code = previous.get(scene, {}).get("exit_code", -1)
            else:
                with log.open("w", encoding="utf-8") as stream:
                    result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
                exit_code = result.returncode
            content = log.read_text(encoding="utf-8")
            issues = [line for line in content.splitlines() if re.match(r"FAIL |SCRIPT ERROR:|ERROR:", line)
                      and "resources still in use at exit" not in line]
            summaries = re.findall(r"^(?:[A-Z_]+(?:COMPLETE|DONE|TEST).*failures=\d+.*|[A-Z_]+ checks=\d+ failures=\d+)\r?$", content, re.MULTILINE)
            passed = exit_code == 0 and not issues and bool(summaries) and all(re.search(r"failures=0\b", line) for line in summaries)
            entry = {"scene": scene, "passed": passed, "exit_code": exit_code, "issues": issues,
                     "summaries": summaries, "log": str(log)}
        except subprocess.TimeoutExpired:
            entry = {"scene": scene, "passed": False, "issues": ["timeout"], "log": str(log)}
        print(json.dumps(entry, ensure_ascii=True), flush=True)
        return entry

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(run, args.scenes))
    summary_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    return 0 if all(entry["passed"] for entry in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
