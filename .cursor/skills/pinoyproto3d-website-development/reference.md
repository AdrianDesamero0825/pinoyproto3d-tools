# Website Development Reference

Read this file only for tasks involving live previews, image placement, or downloads.

## Preview and export

- The visible preview and downloaded PNG must use the same native canvas state.
- Keep canvas dimensions explicit and preserve the intended aspect ratio.
- Use `canvas.toBlob(..., "image/png")` for PNG downloads.
- Do not use `html2canvas` or `foreignObjectRendering` unless explicitly requested.
- Apply image fit, transforms, pan, zoom, blur, dimming, borders, backgrounds, and text wrapping in the canvas renderer.
- Verify both the displayed canvas dimensions and the PNG's intrinsic dimensions.
- For 3:4 social graphics, use the requested high-resolution target, such as 1080×1440, while scaling the displayed canvas through CSS.

## Targeted validation

For a preview/export change, test only the affected page and relevant interactions:

1. Page loads without console errors.
2. Changed controls update the preview.
3. Preview remains usable at the relevant viewport.
4. Export downloads the expected file.
5. Export dimensions and preview state match the requirement.

## Project references

- `index.html`: main tools landing page.
- `tools/customer-feedback.html`: native canvas rendering and PNG download reference.
- `tools/new-tool.html`: Carousel and Layout Builder implementation.

## Typography and structure

Use this Google Fonts family set for future pages:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Anton&family=Bebas+Neue&family=Montserrat:ital,wght@0,300;0,400;1,300;1,400&display=swap" rel="stylesheet">
```

Preferred roles:

- `Bebas Neue`: display headings where a condensed title is useful.
- `Anton`: strong hero headings, banners, and high-impact labels.
- `Montserrat` weight 300: light supporting copy.
- `Montserrat` weight 400: body text, forms, navigation, and controls.

Preferred production structure:

```text
/
├── index.html
├── tools/
│   ├── customer-feedback.html
│   ├── quotation-maker.html
│   └── new-tool.html
├── assets/
│   ├── css/
│   ├── js/
│   ├── fonts/
│   └── images/
└── .cursor/
    └── skills/
```

Do not perform a full migration just to satisfy this structure. Add shared assets when a style or behavior is reused by multiple pages, and preserve working inline code until migration is safe and validated.
