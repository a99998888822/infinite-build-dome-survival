#!/usr/bin/env python3
"""Generate an image through RightAPI without ever storing the API token."""

from __future__ import annotations

import argparse
import base64
import gzip
import json
import mimetypes
import os
import re
import sys
import urllib.request
import urllib.error
import zlib
import time
from pathlib import Path


DRAW_URL = "https://www.rightapi.ai/draw/v1/images/generations"
TASK_URL = "https://www.rightapi.ai/v1/tasks/{task_id}"
TASK_LOG = Path("artifacts/generated/.rightapi_tasks.jsonl")
COMMON_HEADERS = {
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    "Accept-Encoding": "gzip, deflate, br",
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/131.0.0.0 Safari/537.36"
    ),
    "Origin": "https://www.rightapi.ai",
    "Referer": "https://www.rightapi.ai/",
}
MODELS = {
    "nano-banana-2-lite",
    "nano-banana-2",
    "nano-banana-pro",
    "gpt-image-2",
    "gpt-image-2-vip",
    "gpt-image-2.5",
    "gpt-image-2.5-flare",
    "gpt-image-2.5-sunburst",
}


def read_json(url: str, request: urllib.request.Request) -> dict:
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            raw = response.read()
            status = response.status
            content_encoding = (response.headers.get("Content-Encoding") or "").lower()
    except urllib.error.HTTPError as error:
        body = error.read(512).decode("utf-8", errors="replace")
        raise RuntimeError(f"RightAPI HTTP {error.code}: {body[:240]}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"RightAPI network error: {error.reason}") from error
    if status < 200 or status >= 300:
        raise RuntimeError(f"RightAPI HTTP {status}")
    if content_encoding == "gzip":
        try:
            raw = gzip.decompress(raw)
        except OSError as error:
            raise RuntimeError("RightAPI returned invalid gzip data") from error
    elif content_encoding == "deflate":
        try:
            raw = zlib.decompress(raw)
        except zlib.error as error:
            raise RuntimeError("RightAPI returned invalid deflate data") from error
    if not raw.strip():
        raise RuntimeError(f"RightAPI returned an empty response from {url}")
    try:
        data = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        preview = raw[:240].decode("utf-8", errors="replace")
        raise RuntimeError(f"RightAPI returned non-JSON data: {preview!r}") from error
    if not isinstance(data, dict):
        raise RuntimeError("RightAPI returned a JSON value that is not an object")
    return data


def image_data_url(path: Path) -> str:
    mime_type, _ = mimetypes.guess_type(path.name)
    if mime_type not in {"image/png", "image/jpeg", "image/webp", "image/gif"}:
        raise ValueError(f"unsupported reference image type: {path}")
    if not path.is_file():
        raise FileNotFoundError(f"reference image not found: {path}")
    if path.stat().st_size > 50 * 1024 * 1024:
        raise ValueError(f"reference image exceeds 50 MB: {path}")
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def append_task_record(record: dict[str, object], task_log: Path) -> None:
    task_log.parent.mkdir(parents=True, exist_ok=True)
    with task_log.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, ensure_ascii=True) + "\n")


def find_task_record(task_id: str, task_log: Path) -> dict[str, object] | None:
    if not task_log.is_file():
        return None
    for line in reversed(task_log.read_text(encoding="utf-8").splitlines()):
        try:
            record = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(record, dict) and record.get("task_id") == task_id:
            return record
    return None


def _read_token() -> str | None:
    token = os.environ.get("NANOBANANA_API_TOKEN")
    if token:
        return token
    if os.name == "nt":
        try:
            import winreg

            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
                token, _ = winreg.QueryValueEx(key, "NANOBANANA_API_TOKEN")
            if isinstance(token, str) and token:
                return token
        except (FileNotFoundError, OSError, winreg.error):
            pass
    return None


def request_image(
    prompt: str,
    model: str,
    poll_seconds: float,
    timeout_seconds: float,
    images: list[Path],
    task_log: Path,
    output_path: Path,
    resume_task_id: str | None = None,
) -> str:
    token = _read_token()
    if not token:
        raise RuntimeError("NANOBANANA_API_TOKEN is not set in the process or Windows user environment")
    if model not in MODELS:
        raise ValueError(f"unsupported model: {model}")
    if resume_task_id:
        task_id = resume_task_id
        saved = find_task_record(task_id, task_log)
        if saved is None:
            raise RuntimeError(f"task ID is not present in task log: {task_id}")
    else:
        payload_data: dict[str, object] = {
            "model": model,
            "prompt": prompt,
            "n": 1,
            "size": "9:16",
            "imageSize": "2K",
            "async": True,
        }
        if images:
            payload_data["image"] = [image_data_url(path) for path in images]
        payload = json.dumps(payload_data, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            DRAW_URL,
            data=payload,
            headers={
                **COMMON_HEADERS,
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        data = read_json(DRAW_URL, request)
        task_id = data.get("task_id")
        if not isinstance(task_id, str) or not task_id:
            raise RuntimeError("RightAPI draw submission did not return task_id")
        append_task_record(
            {
                "submitted_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "task_id": task_id,
                "model": model,
                "output": str(output_path),
                "status": "submitted",
            },
            task_log,
        )
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        task_url = TASK_URL.format(task_id=task_id)
        task_request = urllib.request.Request(
            task_url,
            headers={**COMMON_HEADERS, "Authorization": f"Bearer {token}"},
        )
        task = read_json(task_url, task_request)
        status = task.get("status") or task.get("state")
        result_data = task.get("data")
        candidates = task.get("candidates")
        # Some Images-compatible completed responses omit status and expose
        # the result directly as data/candidates. Treat those as completed.
        direct_result = isinstance(result_data, list) or isinstance(candidates, list)
        if status is None and direct_result:
            status = "completed"
        if status in {"queued", "processing", "in_progress", "pending"}:
            time.sleep(poll_seconds)
            continue
        if status == "failed":
            error = task.get("error", {})
            detail = error.get("message", "unknown task error") if isinstance(error, dict) else str(error)
            append_task_record(
                {"task_id": task_id, "status": "failed", "error": detail},
                task_log,
            )
            raise RuntimeError(f"RightAPI task failed: {detail}")
        if status not in {"completed", "success", "succeeded"}:
            raise RuntimeError(f"RightAPI task returned unexpected status: {status!r}")
        if isinstance(result_data, list):
            for item in result_data:
                if isinstance(item, dict) and isinstance(item.get("url"), str):
                    append_task_record(
                        {"task_id": task_id, "status": "completed", "url": item["url"]},
                        task_log,
                    )
                    return item["url"]
                if isinstance(item, dict) and isinstance(item.get("b64_json"), str):
                    raise RuntimeError("RightAPI returned base64; this helper currently requires a result URL")
        if isinstance(candidates, list):
            for item in candidates:
                if isinstance(item, dict) and isinstance(item.get("url"), str):
                    append_task_record(
                        {"task_id": task_id, "status": "completed", "url": item["url"]},
                        task_log,
                    )
                    return item["url"]
        raise RuntimeError("RightAPI task completed without data URL or supported result")
    raise RuntimeError(f"RightAPI task timed out after {timeout_seconds:.0f}s: {task_id}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--model", default="nano-banana-2", choices=sorted(MODELS))
    parser.add_argument("--poll-seconds", type=float, default=3.0)
    parser.add_argument("--timeout-seconds", type=float, default=300.0)
    parser.add_argument("--image", action="append", type=Path, default=[])
    parser.add_argument("--task-log", type=Path, default=TASK_LOG)
    parser.add_argument("--resume-task")
    args = parser.parse_args()
    args.task_log.parent.mkdir(parents=True, exist_ok=True)
    url = request_image(
        args.prompt,
        args.model,
        args.poll_seconds,
        args.timeout_seconds,
        args.image,
        args.task_log,
        args.output,
        args.resume_task,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(url, timeout=120) as response:
            image_bytes = response.read()
            content_type = response.headers.get_content_type()
    except (urllib.error.HTTPError, urllib.error.URLError) as error:
        raise RuntimeError(f"image download failed: {error}") from error
    if not image_bytes:
        raise RuntimeError("image URL returned an empty body")
    if content_type not in {"image/png", "image/jpeg", "image/webp", "image/gif"}:
        if not image_bytes.startswith((b"\x89PNG", b"\xff\xd8", b"RIFF", b"GIF8")):
            raise RuntimeError(f"image URL returned unexpected content type: {content_type}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image_bytes)
    append_task_record(
        {"status": "downloaded", "output": str(args.output), "url": url},
        args.task_log,
    )
    print(args.output)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"rightapi_generate: {error}", file=sys.stderr)
        raise SystemExit(1)
