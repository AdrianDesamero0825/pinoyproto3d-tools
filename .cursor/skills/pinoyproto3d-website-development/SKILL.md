---
name: pinoyproto3d-website-development
description: Develop and maintain the PinoyProto 3D website using its existing HTML, CSS, and JavaScript patterns. Use for website edits, live-preview behavior, PNG export matching, responsive design, browser validation, or requests to keep new pages consistent with the site's tools.
---

# PinoyProto 3D Website Development

Use this skill only for website-development tasks in this repository.

## Core rules

- Inspect only the relevant target page, comparable page, and directly related assets before editing.
- Preserve the PinoyProto 3D dark navy/orange visual language:
  - `#0d141c` or the page's existing dark background
  - orange accent near `#ff7200`
  - muted text near `#9eacbd`
  - bordered rounded panels
  - responsive layouts with mobile breakpoints
- Reuse existing page structure, labels, controls, and terminology where possible.
- Prefer self-contained page implementations when the surrounding tool uses inline CSS and JavaScript.
- Keep changes surgical; do not rewrite unrelated tools or remove user changes.
- Keep user-facing errors explicit. Do not silently fall back when rendering or export fails.

For detailed preview/export rules, read [reference.md](reference.md) only when the task involves rendering or downloads.

## Workflow

1. Inspect the target page and a comparable existing tool.
2. Identify all affected controls, preview elements, export actions, and assets.
3. Implement the smallest complete change using existing patterns.
4. Run the smallest targeted validation for the changed page and interactions.
5. Review the diff and report unrelated pre-existing warnings separately.

## Existing project patterns

- `index.html` is the main tools landing page.
- Tool pages live under `tools/`.
- `tools/customer-feedback.html` is the reference for native canvas rendering and PNG download using `canvas.toBlob`.
- `tools/new-tool.html` contains the Carousel and Layout Builder and its inline preview/export behavior.
- Navigation links should be kept consistent across tool pages.
