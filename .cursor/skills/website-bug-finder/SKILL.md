---
name: website-bug-finder
description: Find, reproduce, diagnose, and fix website defects in behavior, rendering, data handling, and security. Use when the user asks to find bugs, debug a website, investigate a failure, or review code for defects.
---

# Website Bug Finder

## Workflow

1. Map the affected route, control, input, expected result, actual result, and relevant code path.
2. Reproduce the issue in a browser or with the narrowest reliable check. If reproduction is unavailable, state that the finding is source-based.
3. Trace the cause and check nearby edge cases: empty values, unusual characters, long content, repeated actions, network errors, permissions, and mobile layouts.
4. Check security-sensitive boundaries when relevant: untrusted HTML, URL construction, file uploads, authentication, authorization, exposed data, and storage policies.
5. Fix only when requested or clearly implied. Keep the patch focused and verify the original reproduction plus the affected neighboring flow.

## Finding quality

- Report defects, not personal style preferences.
- Give each finding a severity based on reach and impact; include a concise reproduction, expected/actual behavior, evidence, and affected location.
- Distinguish confirmed defects from plausible risks and from backend questions that cannot be answered from repository code.
- Check whether unescaped content enters `innerHTML`; prefer safe DOM text APIs or context-appropriate escaping.
- Do not label public client configuration as a secret by itself. Verify the access controls that make a public key safe, and report backend policy gaps as unverified when those policies are unavailable.
- Avoid reporting generated/template markup as duplicate IDs or broken references without checking how it renders.

## Report format

Order findings from highest to lowest severity. Include a short test/status summary and note what could not be reproduced. For fixes, summarize the cause, change, and verification.
