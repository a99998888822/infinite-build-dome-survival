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

For the Images-compatible endpoint, reference images are passed as a top-level `image` array of data URLs, not as OpenAI chat `messages` content parts:

```json
{
  "model": "nano-banana-pro",
  "prompt": "Use the supplied references for style only...",
  "n": 1,
  "size": "9:16",
  "imageSize": "2K",
  "async": true,
  "image": ["data:image/png;base64,..."]
}
```

The submission response returns a task ID. Poll the task endpoint, which is site-level and does not include `/draw`:

```text
GET https://www.rightapi.ai/v1/tasks/{task_id}
Authorization: Bearer $NANOBANANA_API_TOKEN
```

Poll while `status` is `queued`, `processing`, or `in_progress`. When `status` is `completed`, read the image URL from `data[0].url` (or the documented compatible result field). When `status` is `failed`, report `error.message` and do not create an output asset. Apply a bounded timeout and a short polling interval.

Operational rule: write the returned `task_id` to a local task log immediately after submission. If the client fails during polling, query that task ID again; do not submit a duplicate image request. A 2xx submission followed by a client-side gzip or JSON parsing error must be treated as an active task, not as a safe-to-retry failure.

The completed Images response is shaped like:

```text
{"data":[{"url":"https://cdn.example.com/results/task.png"}]}
```

Extract the URL, download it, and inspect the actual file. Do not use `/v1/chat/completions` for drawing tasks. Models advertised by this project are:

- `nano-banana-2-lite`
- `nano-banana-2`
- `nano-banana-pro`
- `gpt-image-2`
- `gpt-image-2-vip`
- `gpt-image-2.5`
- `gpt-image-2.5-flare`
- `gpt-image-2.5-sunburst`

Do not put a real token in examples, fixtures, logs, or source control.
## Token lookup

The bundled generator reads `NANOBANANA_API_TOKEN` from the process environment. On Windows, when the process variable is absent, it falls back to the current user's `HKCU\Environment` value with the same name. It never prints or persists the token.
