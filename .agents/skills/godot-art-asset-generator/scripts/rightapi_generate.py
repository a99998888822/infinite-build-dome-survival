#!/usr/bin/env python3
"""Generate an image through RightAPI without ever storing the API token."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path


DRAW_URL = "https://www.rightapi.ai/draw/v1/images/generations"
TASK_URL = "https://www.rightapi.ai/v1/tasks/{task_id}"
MODELS = {
    "nano-banana-2-lite",
    "nano-banana-2",
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
    except urllib.error.HTTPError as error:
        body = error.read(512).decode("utf-8", errors="replace")
        raise RuntimeError(f"RightAPI HTTP {error.code}: {body[:240]}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"RightAPI network error: {error.reason}") from error
    if status < 200 or status >= 300:
        raise RuntimeError(f"RightAPI HTTP {status}")
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


def request_image(prompt: str, model: str, poll_seconds: float, timeout_seconds: float) -> str:
    token = os.environ.get("NANOBANANA_API_TOKEN")
    if not token:
        raise RuntimeError("NANOBANANA_API_TOKEN is not set")
    if model not in MODELS:
        raise ValueError(f"unsupported model: {model}")
    payload = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "async": True,
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        DRAW_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    data = read_json(DRAW_URL, request)
    task_id = data.get("task_id")
    if not isinstance(task_id, str) or not task_id:
        raise RuntimeError("RightAPI draw submission did not return task_id")
    deadline = __import__("time").monotonic() + timeout_seconds
    while __import__("time").monotonic() < deadline:
        task_url = TASK_URL.format(task_id=task_id)
        task_request = urllib.request.Request(task_url, headers={"Authorization": f"Bearer {token}"})
        task = read_json(task_url, task_request)
        status = task.get("status")
        if status in {"queued", "in_progress"}:
            __import__("time").sleep(poll_seconds)
            continue
        if status == "failed":
            error = task.get("error", {})
            detail = error.get("message", "unknown task error") if isinstance(error, dict) else str(error)
            raise RuntimeError(f"RightAPI task failed: {detail}")
        if status != "completed":
            raise RuntimeError(f"RightAPI task returned unexpected status: {status!r}")
        result_data = task.get("data")
        if isinstance(result_data, list):
            for item in result_data:
                if isinstance(item, dict) and isinstance(item.get("url"), str):
                    return item["url"]
                if isinstance(item, dict) and isinstance(item.get("b64_json"), str):
                    raise RuntimeError("RightAPI returned base64; this helper currently requires a result URL")
        candidates = task.get("candidates")
        if isinstance(candidates, list):
            for item in candidates:
                if isinstance(item, dict) and isinstance(item.get("url"), str):
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
    args = parser.parse_args()
    url = request_image(args.prompt, args.model, args.poll_seconds, args.timeout_seconds)
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
    print(args.output)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"rightapi_generate: {error}", file=sys.stderr)
        raise SystemExit(1)
