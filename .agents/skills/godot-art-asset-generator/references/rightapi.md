# RightAPI reference

Base URL: `https://www.rightapi.ai`

RightCodes drawing is asynchronous. Image generation uses:

```text
POST https://www.rightapi.ai/draw/v1/images/generations
Authorization: Bearer $NANOBANANA_API_TOKEN
Content-Type: application/json
```

Example request shape:

```json
{
  "model": "nano-banana-2",
  "prompt": "Generate one transparent pixel-art sprite...",
  "async": true
}
```

The submission response returns a task ID. Poll the task endpoint, which is site-level and does not include `/draw`:

```text
GET https://www.rightapi.ai/v1/tasks/{task_id}
Authorization: Bearer $NANOBANANA_API_TOKEN
```

Poll while `status` is `queued` or `in_progress`. When `status` is `completed`, read the image URL from `data[0].url` (or the documented compatible result field). When `status` is `failed`, report `error.message` and do not create an output asset. Apply a bounded timeout and a short polling interval.

The completed Images response is shaped like:

```text
{"data":[{"url":"https://cdn.example.com/results/task.png"}]}
```

Extract the URL, download it, and inspect the actual file. Do not use `/v1/chat/completions` for drawing tasks. Models advertised by this project are:

- `nano-banana-2-lite`
- `nano-banana-2`
- `gpt-image-2`
- `gpt-image-2-vip`
- `gpt-image-2.5`
- `gpt-image-2.5-flare`
- `gpt-image-2.5-sunburst`

Do not put a real token in examples, fixtures, logs, or source control.
