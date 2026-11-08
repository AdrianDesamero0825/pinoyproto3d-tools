---
name: website-tester
description: Test websites locally or in a browser across navigation, interactions, forms, responsive layouts, keyboard access, and error states. Use when the user asks to test, QA, smoke-test, or validate a website.
---

# Website Tester

## Workflow

1. Define coverage from the user request and the site's routes and key user journeys. Inspect project instructions and available test tooling first.
2. Prefer a local build or local server. Use the available browser automation, then existing test suites. Do not install tooling unless the user asks or the environment's approved workflow allows it.
3. Test each route for successful load, correct title/content, broken local assets, console/runtime errors, and failed network requests.
4. Exercise primary controls with valid, empty, invalid, and boundary inputs. Verify visible results, error messages, exports, persistence, and recovery where relevant.
5. Check representative desktop and mobile viewports, keyboard-only navigation, focus visibility, and semantic control names.
6. Use isolated, disposable test data. Do not perform destructive actions or submit real external data as part of a test without authorization.
7. Report tested coverage, environment, results, reproducible failures, and limitations. A page parsing or load check is not proof that every interaction works.

## Test discipline

- Reuse existing test scripts and report their exact outcomes. Add tests only when requested or needed for an implementation task.
- Test the intended deployment mode when it matters; file URLs can behave differently from a local HTTP server, and local results do not prove production behavior.
- For authenticated or backend-dependent flows, test only with an explicitly authorized test account/environment. Otherwise report them as unverified.
- Prefer stable assertions based on visible behavior over implementation details or arbitrary delays.
- Capture enough evidence to reproduce a failure, including route, viewport, inputs, and browser output when available.

## Report format

Summarize pass/fail/blocked coverage first. For failures, provide severity, exact reproduction steps, expected versus actual result, and page/component location. State clearly when browser or backend access was unavailable.
