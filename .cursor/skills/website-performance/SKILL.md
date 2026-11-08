---
name: website-performance
description: Audit or improve website loading speed, responsiveness, asset weight, rendering cost, caching, and Core Web Vitals. Use when the user asks to optimize, speed up, profile, or reduce resource use on a website.
---

# Website Performance

## Workflow

1. Establish scope: target routes, device/network conditions, and whether this is an audit or an implementation request.
2. Measure before changing code when a browser or performance tool is available. Record the URL, viewport, device profile, cache state, and tool used.
3. Inspect transfer sizes, request count, image dimensions/formats, JavaScript and CSS cost, render-blocking resources, third-party requests, long tasks, layout shifts, and data/API payload sizes.
4. Separate measured results from source-based risks. Do not claim a Core Web Vitals pass from a local source inspection alone.
5. Rank fixes by user impact and effort. Implement only when asked to change the site, then repeat the same measurements and compare results.

## Review areas

- Compare real user field data at the 75th percentile with lab measurements. Check current official Core Web Vitals thresholds when reporting numeric targets; they can change.
- Prioritize the largest visible content, critical request chains, oversized assets, unnecessary startup JavaScript, repeated downloads, and expensive interactions on low-powered mobile devices.
- Inspect image source dimensions against rendered size; recommend responsive sources, modern formats, compression, explicit layout dimensions, and lazy loading for below-the-fold images where appropriate.
- Check whether large uploads are resized before decode, canvas work, storage, or database transfer.
- Inspect data queries for `select *`, large JSON/blob columns, unbounded result sets, repeated requests, and missing pagination or server-side aggregation.
- Defer or lazy-load optional code such as PDF, image-export, analytics, and editor libraries until the relevant feature is used.
- Treat CDN, fonts, and third-party scripts as both latency and reliability dependencies. Verify current versioning/integrity options rather than assuming a CDN is faster.
- Avoid premature caching, bundling, or code splitting that adds complexity without measured benefit.

## Report format

For each issue, include page/resource, measured evidence or source location, likely user impact, priority, and a practical fix. Include unresolved measurement needs and identify any tool limitations. Do not invent scores or savings estimates.
