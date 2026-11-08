---
name: website-accessibility-seo
description: Audit or improve website accessibility, semantic HTML, keyboard and screen-reader behavior, metadata, crawlability, and search previews. Use when the user asks for accessibility, WCAG, SEO, discoverability, or a production-ready website review.
---

# Website Accessibility and SEO

## Workflow

1. Establish whether the site is public, private, or an internal tool; use that to scope search and sharing recommendations.
2. Inspect page structure, headings, landmarks, labels, accessible names, focus order, contrast, error announcements, image alternatives, and responsive zoom behavior.
3. Test keyboard interactions and screen-reader-relevant semantics in a browser when available. Use automated checks as a supplement, not as proof of conformance.
4. Inspect titles, descriptions, canonical URLs, social preview metadata, robots directives, sitemap/robots files, structured data, and crawlable links where relevant.
5. Check current WCAG/WAI and search documentation for normative or time-sensitive recommendations.
6. Report confirmed barriers separately from SEO enhancements; implement only when requested and verify affected pages.

## Principles

- Use native HTML controls and landmarks before adding ARIA. ARIA must match the actual interaction and state.
- Ensure every form control has a programmatic label, errors are perceivable, keyboard focus is visible, and interactive controls work without a pointer.
- Do not infer WCAG conformance from color inspection or automated scans alone; name the criteria and coverage actually evaluated.
- For public pages, make titles/descriptions unique and useful, ensure important content is crawlable, and provide accurate social metadata when sharing matters.
- For internal tools, avoid prioritizing public SEO before privacy, access control, and user task completion.
- Never expose private customer, transaction, or business data merely to make pages indexable.

## Report format

For each finding, include page, user or crawl impact, evidence, priority, and a fix. State which assistive technologies, viewports, and automated tools were actually tested.
