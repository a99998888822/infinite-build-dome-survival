---
name: godot-art-asset-generator
description: Generate, transform, and validate Godot-ready pixel-art sprites and other game art with the project's RightAPI image models. Use when creating or redrawing player sprites, animation sheets, UI art, icons, backgrounds, or effects; preserve project references, dimensions, transparency, and pixel-art constraints.
---

# Godot Art Asset Generator

Use this skill for project art generation through `https://www.rightapi.ai`. Keep generated resources reviewable and do not overwrite shipped assets until the user explicitly approves them.

## Credentials and API

- Read `NANOBANANA_API_TOKEN` from the process environment first; on Windows, if it is absent there, automatically read the same variable from the current user environment registry.
- Never write the token to this skill, project files, logs, command history, generated metadata, or an inline shell assignment. If it is missing from both locations, stop and ask the user to set it locally; never paste or echo the secret.
- Use the RightCodes asynchronous image endpoint `https://www.rightapi.ai/draw/v1/images/generations`.
- Send `Authorization: Bearer $NANOBANANA_API_TOKEN` and JSON with `model`, `prompt`, and `async: true` (plus supported image parameters when needed).
- The submission response contains `task_id`; poll `GET https://www.rightapi.ai/v1/tasks/{task_id}` without the `/draw` prefix until `status` is `completed`.
- Continue polling for `queued` and `in_progress`; stop with a sanitized error for `failed`, unexpected status, timeout, or completed tasks without `data[].url`/supported result data.
- Supported models: `nano-banana-2-lite`, `nano-banana-2`, `nano-banana-pro`, `gpt-image-2`, `gpt-image-2-vip`, `gpt-image-2.5`, `gpt-image-2.5-flare`, and `gpt-image-2.5-sunburst`.
- Prefer `nano-banana-2` for pixel sprites; use `nano-banana-2-lite` for quick drafts and a GPT image model when the user requests higher fidelity or the Nano model fails to produce a usable image.
- Use `nano-banana-pro` when the user explicitly requests that model for a high-fidelity character or illustration.
- The response commonly contains a Markdown image URL. Download that URL immediately to a review output under `artifacts/generated/`; do not assume the API returns base64.
- Before any paid request, validate the token, model name, reference paths, image MIME types, and output path locally.
- Default to one image (`n=1`) and one submission. Do not generate variants or retry a request after a submission response unless the user explicitly approves another paid attempt.
- As soon as a submission returns `task_id`, persist it in `artifacts/generated/.rightapi_tasks.jsonl` without storing the token, prompt, or base64 image data.
- If polling fails, times out, or the client crashes after submission, resume with the saved task ID before submitting anything new. Never treat an unknown task state as a reason to create another task.

Use the bundled `scripts/rightapi_generate.py` for requests. It submits the asynchronous draw task, polls the task endpoint, validates HTTP status and JSON at every step, extracts the completed image URL, and validates the downloaded image body. Never treat an empty response, prose-only response, missing task ID, failed task, timeout, or non-image response as a generated asset. Save each attempt under a unique output filename so stale files cannot be mistaken for a new result.

## Project workflow

1. Inspect the target asset, all scene/script references, current dimensions, color mode, frame count, and import settings with `rg`, Pillow, and Godot files.
2. Choose a non-destructive output path such as `artifacts/generated/<asset-name>/` and preserve the original until review.
3. Build a precise prompt from the reference: silhouette, facing direction, pose, frame layout, canvas size, palette, contrast against the actual scene, and transparency requirements.
4. Request strict pixel art: nearest-neighbor blocks, hard edges, no antialiasing, no gradients, limited palette, no text, and no unintended objects. For animation, state the exact cell layout and distinct poses.
5. Download the returned image. Inspect it visually and with Pillow. If the provider returns checkerboard or a solid background, remove only the connected outer background. Do not globally delete white pixels because white may be part of the character.
6. Resize with `Image.Resampling.NEAREST`, convert to RGBA, and verify the exact dimensions and alpha bounding box. For spritesheets, verify each frame independently.
7. Validate the candidate in Godot through a candidate-specific duplicate scene or runtime harness that loads the new path directly. Do not temporarily overwrite an existing source file or only edit a script constant: Godot import caches can make screenshots display the old `.ctex`. Run the editor import pass first, capture a candidate screenshot, and compare it against a baseline or inspect the candidate region to prove the new pixels are visible. Restore the original reference after review unless the user explicitly requests replacement.
8. Report the generated path, model used, dimensions, transparency result, validation command/result, and any known limitations. Include an absolute-path image link for visual review.

## Cost and recovery workflow

1. Build and review the prompt locally before calling the paid endpoint. Use one reference set and one output size.
2. Run the script's preflight checks. A missing token, missing reference, unsupported MIME type, existing output, or unsupported model must fail before network submission.
3. Submit exactly once. Immediately persist the returned `task_id` and intended output path to `.rightapi_tasks.jsonl`.
4. Poll the saved task ID. If the process stops, run the same command with `--resume-task <task_id>`; do not submit a duplicate request.
5. Download only a validated image URL. Record completion and output path in the task log.
6. Only retry after a pre-submission failure such as a local validation error or a clearly rejected HTTP request with no `task_id`. Never retry after a 2xx response, a gzip/JSON parsing error, or an unknown task status until the original task has been queried.
7. Use `nano-banana-2-lite` for optional exploratory drafts and `nano-banana-pro` only for an approved final. Do not spend final-model credits on speculative prompt experiments.

## Sprite rules

- Match the project's existing reference asset format before choosing output dimensions. Common combat assets use `54x54`; the compact reference uses `64x64`; four-frame horizontal sheets use `4 * frame_width` by `frame_height`.
- Keep the baseline and pivot stable across animation frames.
- Ensure readability against the actual battle background. Use contrast, a restrained outline, or a small accent rather than increasing detail or power fantasy.
- Do not claim a sheet is animated unless its frames have visibly different poses and correct per-frame alignment.
- Keep Godot texture filtering nearest and do not hand-create `.gd.uid` files.

## Four asset pipelines

### Characters and monsters

Use `nano-banana-2` for character identity and reference consistency. Use `nano-banana-2-lite` for rough pose exploration and `gpt-image-2.5-sunburst` for a high-quality final keyframe when needed. Do not trust an AI-generated spritesheet to have correct grid cells or a real walk cycle. Generate idle, walk, attack, hurt, and other keyframes as separate images using the same reference character, then align their baseline, crop, resize, and assemble the sheet or Godot `SpriteFrames` resource.

Prompt for a keyframe should specify the reference silhouette, facing direction, fixed canvas, stable feet baseline, pose, limited palette, thick outline, contrast against the actual project background, transparent background, and the negative constraints `anti-aliasing, blur, sub-pixel, photorealistic, 3d render, text, watermark`.

For this project, inspect the target before choosing dimensions. Combat assets commonly use `54x54`; the compact reference uses `64x64`; four-frame sheets are `216x54` or `256x64` respectively. Keep all frame pivots and visible bounds stable.

### Scene props and small assets

Use `nano-banana-2-lite` for rapid variants of rocks, trees, ruins, pickups, weapon icons, effects, and decorative pieces. Use `gpt-image-2` when the request needs a precise count or arranged object board. It is usually safer to generate a large image with isolated objects and generous spacing, then detect connected regions and export individual PNGs. Do not rely on the model to produce mathematically seamless tiles or exact tiny `16x16` tiles; generate a larger source and manually or programmatically correct edges.

### UI layout and decoration

Use `gpt-image-2` for layout, panel hierarchy, lists, buttons, drawers, and multi-region composition. Use `gpt-image-2.5` for higher-fidelity style studies. Ask for a layout reference or decorative panel shapes with empty areas reserved for real text. Do not use generated text, numbers, or Chinese labels as production UI content. Rebuild interactive controls and text with Godot `Control` nodes, project fonts, and existing theme resources. Generate borders, wood/metal panels, and ornaments as separate transparent assets when possible. Match existing resources under `assets/ui/` instead of inventing a disconnected visual language.

### Backgrounds and large illustrations

Use `gpt-image-2.5-sunburst` for final large scenes, parallax backgrounds, and major illustrations; use `gpt-image-2-vip` for very large or composition-heavy variants. Do not request an 8K ultra-wide scene in one pass. Generate separate background, midground, foreground, and effects layers, or split a panorama into manageable regions, then compose them in Godot with parallax nodes. Explicitly reserve an empty gameplay area, exclude characters and UI, and avoid repeated tiled patterns. Full-body character illustrations are a separate high-resolution asset class and should not be forced into combat sprite dimensions.

### Model decision table

| Need | Model | Generation approach | Required post-processing |
| --- | --- | --- | --- |
| Player or monster idle frame | `nano-banana-2` | One frame plus reference image | Nearest resize, palette reduction, alpha cleanup |
| Player or monster walk cycle | `nano-banana-2` | Independent keyframes, then assemble | Baseline/pivot alignment and frame validation |
| Many small props or icons | `nano-banana-2-lite` | Batch concepts or isolated object board | Connected-region crop and common canvas |
| Precise prop arrangement | `gpt-image-2` | Spaced object board | Region extraction and standardized sizing |
| UI layout study | `gpt-image-2` | Text-free layout reference | Rebuild with Godot controls |
| UI panel decoration | `gpt-image-2` or `gpt-image-2.5` | Individual panel or ornament | Alpha cleanup and nine-patch/layer integration |
| Battle background | `gpt-image-2.5-sunburst` | Separate depth layers | Parallax composition and color matching |
| Large panorama | `gpt-image-2-vip` or `gpt-image-2.5-sunburst` | Split regions or layers | Stitching, crop, and runtime validation |
| Character selection illustration | `nano-banana-2`, `nano-banana-pro`, or `gpt-image-2.5-sunburst` | Single illustration with references | Transparent/plain background and composition check |

### Prompt patterns

For a character keyframe:

```text
Side-view right-facing game character based on the supplied reference, preserve the same silhouette and proportions, centered on a fixed canvas, stable feet baseline, [POSE]. Retro 16-bit pixel art, limited palette, thick dark outline, readable against the project's dark swamp battle background, transparent background, no text, no watermark. Negative constraints: anti-aliasing, blur, sub-pixel, photorealistic, 3d render.
```

For a prop board:

```text
Create a sheet of six isolated swamp-ruin props with generous spacing, matching lighting and the project's limited 16-bit palette. No overlap, no text, no shadows touching neighboring props, transparent background, crisp silhouettes, no anti-aliasing.
```

For a UI layout reference:

```text
Design a dark retro pixel-game battle HUD layout with a compact top status bar, right-side stats drawer, and bottom experience bar. Reserve empty areas for real text. No readable text, fake letters, logos, or watermark. Use the project's bronze, deep green, and charcoal material language with precise rectangular alignment.
```

For a parallax background:

```text
Wide 2D battle background for a dark swamp ruin inside a survival dome. Separate foreground, midground, and background depth, reserve an empty center gameplay area, darker edges, muted green/charcoal/rust/pale-cyan palette, retro 16-bit game art, no characters, no text, no UI, no repeated tile pattern.
```

### Production rules

- Treat generated images as high-resolution source art, not automatically pixel-perfect assets. Every sprite passes nearest-neighbor reduction, palette restriction, anti-alias cleanup, and alpha inspection.
- Use supplied game screenshots and canonical project assets as image references whenever consistency matters; references outperform a long list of style tags.
- Keep raw downloads and processed outputs separate under `artifacts/generated/`.
- Use `SpriteFrames` or individually imported frames when the model output is not a trustworthy grid sheet.
- Validate visual readability in the real battle background, not only on a checkerboard preview.

## Background removal

When transparency is unavailable, prefer a connected-component flood fill from the image border using a tolerance for the known background color. Preserve enclosed regions and interior whites. Save an intermediate raw download and a processed RGBA output so the operation is auditable.

## Failure prevention and recovery

- Do not silently switch models. If the selected model returns an empty `choices` array, non-JSON output, a timeout, or no image URL, report the exact failure class and either retry the same model once or state the explicit fallback model before using it.
- RightCodes image generation is asynchronous. Do not call the chat-completions endpoint for image generation and do not expect the submit response to contain the final image. Always submit with `async: true`, retain `task_id`, poll the site-level task endpoint, and only download after `status=completed`.
- The official Images payload uses top-level `prompt`, `n`, `size`, `imageSize`, `async`, and optional `image` data-URL array. Do not use `messages[].content[].image_url` for this endpoint.
- Treat a 2xx submission as billable/active until proven otherwise. Persist its task ID before parsing any later response fields.
- Handle gzip/deflate response bodies before JSON decoding and accept official `data[0].url` or Gemini-compatible candidate results.
- Use browser-like headers only as a compatibility measure; do not loop on Cloudflare 403/1010. Report the block and stop after one pre-task retry.
- A successful HTTP request is not a successful generation. Require a downloadable image, inspect its dimensions and mode, and reject placeholder files or stale output paths.
- The advertised output size is a target, not evidence that the model honored it. Record the raw dimensions, then document any crop, nearest-neighbor resize, palette quantization, or aspect-ratio correction.
- Never claim runtime validation from a screenshot that still contains the previous asset. Use a unique candidate path, force Godot to import it, and compare the resulting screenshot with the baseline.
- For large backgrounds, keep the center gameplay/menu-safe area explicit in the prompt and inspect the actual composition before integrating. Do not present an unsuitable image merely because it has the right filename and dimensions.
- Keep API diagnostics free of credentials. Store only sanitized errors such as HTTP status, empty response, invalid JSON, missing choices, missing URL, or invalid image content.
- Do not read unrelated skills or generate extra intermediate assets unless they are required for the requested output.

## Validation

Use the project's Godot executable when available. Probe PATH first, then resolve the Godot desktop shortcut. Run:

```text
godot.exe --headless --editor --path <project> --quit
godot.exe --headless --path <project> --scene <scene> --quit-after 120
```

For visible proof, use an existing capture test such as `scenes/tests/battle_hud_damage_test.tscn` with its `--capture-dir` argument or `scenes/debug/ui_visual_audit.tscn`. Verify the resulting PNGs, and create a GIF only from genuinely sequential runtime frames.

## Safety

- Never embed or echo the API token.
- Never overwrite an existing shipped asset without explicit approval.
- Preserve unrelated worktree changes.
- Check for replacement characters or mojibake in edited UTF-8 files and run `git diff --check`.
