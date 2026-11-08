---
name: full-website-quality
description: Coordinate a complete website quality review across design, performance, accessibility, SEO, bugs, security, and browser testing. Use when the user asks for a comprehensive audit, a fully polished/production-ready website, or broad quality improvements.
---

# Full Website Quality Review

Use this skill to coordinate a complete review. Read the focused project skills in `.cursor/skills/` as needed: `website-design-review`, `website-performance`, `website-bug-finder`, `website-tester`, and `website-accessibility-seo`. For this repository, also follow `pinoyproto3d-website-development` when making site changes.

## Workflow

1. Determine whether the user wants an audit, fixes, or both. An audit request alone authorizes read-only review and non-destructive validation; do not silently redesign or rewrite unrelated pages.
2. Inventory routes, frameworks, assets, data flows, deployment configuration, and existing instructions. Identify public versus authenticated surfaces.
3. Review in this order: critical defects/security and data exposure; key task completion; accessibility; performance; responsive visual quality; SEO/discoverability; maintainability and deployment.
4. Validate high-priority claims in the browser or with focused checks where possible. Label source-only conclusions, measurements, assumptions, and blocked checks separately.
5. If fixes are requested, agree on coherent scope from the request, change the smallest complete set, and verify each affected route and main flow. Do not stop after a partial fix when a required verification is still feasible.
6. Recheck for regressions, link/asset failures, console errors, mobile layout issues, and accessibility changes. Summarize changed files and remaining risks.

## Prioritization

- **P0:** data exposure, account compromise, critical business flow unavailable.
- **P1:** major user journey broken, severe accessibility barrier, or substantial load/reliability issue.
- **P2:** common but recoverable defect, noticeable usability/performance issue, or incomplete metadata.
- **P3:** polish or low-impact maintenance improvement.

Score findings by user impact and likelihood. Avoid padding an audit with generic checklist items that have no evidence in this site.

## Final report

Include scope and environment; a short overall assessment; prioritized findings with evidence and fixes; checks passed; unverified areas; and, if implementation occurred, changed files and verification results. Never claim “fully optimized” without measured performance data and representative user-flow coverage.
