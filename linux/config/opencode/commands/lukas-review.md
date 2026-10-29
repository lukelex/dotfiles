---
description: Run /review on the current GitHub PR and submit a review in Lukas's style
---

Use `/review` to analyze the GitHub PR for this branch (or the supplied PR number/URL), then post one review in Lukas's style. $ARGUMENTS

## Prepare context

Identify the repository, canonical PR URL, and exact head/base commits. Read the PR description, previous reviews, discussion, and changes since the last review. Verify earlier concerns against the code, not just resolved threads; don't invent history or imply you personally reviewed it before.

Read the applicable `AGENTS.md` files, `~/dotfiles/docs/software-architecture-rules.md`, and `~/dotfiles/docs/LUKAS_WRITING_STYLE.md`. Repository instructions take precedence over architecture preferences. Use the writing guide for the final comments and summary.

Search the repository for its test strategy and testing standards before reviewing tests. Search both filenames and content: `TESTING.md`, test-strategy documents, `CONTRIBUTING.md`, README testing sections, and docs or package-local guidance. Follow relevant references and read the guidance applicable to the changed code. Capture the document paths and concrete requirements for the delegated review. If no strategy is found, say so in the analysis context and use applicable repository instructions, existing test conventions, and CI configuration as evidence; distinguish inferred conventions from explicit requirements.

## Test scrutiny

Evaluate test adequacy for every behavior change, even when the PR contains no test files. Hold tests to the project's documented standards for test layers, isolation, fixtures, mocking, assertions, determinism, and regression coverage. Passing CI and test counts do not establish adequate coverage.

- Map changed behavior and failure modes to concrete existing or added tests. Read relevant tests beyond the diff. For bug fixes, check whether a regression test would fail on the original defect and pass with the fix.
- Scrutinize whether tests exercise production behavior and assert meaningful observable outcomes. Look for assertions that merely mirror the implementation, mocks that bypass the behavior under review, happy-path-only coverage where important failures changed, brittle implementation coupling, and uncontrolled time, randomness, shared state, or external dependencies. Tie criticism to a concrete consequence and the project's standards rather than a personal testing preference.
- Compare added and changed scenarios with each other and with existing tests for duplicate behavioral coverage. Look for opportunities to merge redundant scenarios or use table-driven/parameterized cases when setup, execution, and assertions are substantially the same. Explain which scenarios overlap and propose a concrete consolidation that preserves distinct boundaries, failure modes, readability, and useful failure diagnostics. Follow the project's conventions; do not merge unrelated behaviors merely because their test code looks similar. Treat worthwhile consolidation as a Minor improvement unless there is evidence of a more serious consequence.
- When no tests are submitted, explicitly investigate whether existing tests cover the changed behavior and whether the project requires new coverage. Assess any rationale for omitting tests against the strategy and the actual change. Do not assume an omission is acceptable because the implementation looks correct or CI passes; equally, do not demand redundant tests for changes already adequately covered or exempted by project guidance.
- Report missing or weak tests as actionable findings when they leave a meaningful changed behavior unprotected or violate an applicable testing requirement. Identify the uncovered scenario, cite the relevant standard when available, and propose the appropriate test layer and observable assertion. A test finding does not require proving a production bug already exists.

## Delegate to /review

Use `opencode api` with its configured authentication; JSON-encode payloads instead of interpolating PR text into shell commands. Execute sequentially:

1. `post /api/session --data <JSON>` with `{"title":"lukas-review: PR analysis","location":{"directory":"<absolute repository directory>"}}`. Read `data.id` as `<id>`. Include the current model and agent if known, using the documented API shapes; don't guess or auto-approve permissions.
2. `post /api/session/<id>/command --data <JSON>` with `{"name":"review","text":"<PR URL and analysis instructions>"}`. Include the prepared context, discovered testing standards, and the full Test scrutiny requirements above, and require the full PR at the captured commits, not uncommitted changes. Require an internal assessment of coverage for changed behavior, including the rationale when no new tests are needed. Ask for findings with diff locations, consequences, and proposed fixes, or "Looks good to me." Require analysis only: no GitHub posts, file changes, commits, or `/lukas-review` invocation. Include the validation-summary ban below for user-facing output, but not this orchestration or the posting instructions.
3. `post /api/experimental/session/<id>/wait`, then `get /api/session/<id>`. Proceed only when `data.outcome` is `succeeded`.
4. `get '/api/session/<id>/message?type=assistant&order=asc'`. Read assistant text; follow `cursor.next` with the same type filter and no `order`. Retrieve any delegated child result too. Empty output or a launch acknowledgment is not a clean review.

If the API, command, permissions, or analysis blocks completion, stop and explain why, retaining the session ID for resumption. Never bypass permissions or silently substitute independent analysis or a copied `/review` prompt.

## Verify and post

Only this parent session posts to GitHub. Verify findings against the current diff, dropping duplicates, unsupported claims, and style preferences presented as bugs. Rerun `/review` if the PR head changed during analysis. Do not modify the PR branch.

Classify findings for the approval decision:
- **Major**: likely causes serious data loss, security exposure, broad outage, or a core workflow becoming unusable.
- **Medium**: a real bug or regression that affects a meaningful case and should be fixed before merging; or a material test gap that leaves important changed behavior unprotected or fails an explicit project testing requirement necessary for this change.
- **Minor**: a limited or non-blocking issue, edge case, or improvement.

Post findings inline where supported: severity, short title, precise diff lines, consequence, and a concrete fix. Use a GitHub `suggestion` for an exact replacement; otherwise a concise code example fitting the repository. Don't invent APIs or unrelated refactors.

Verify test findings against the cited standards and existing coverage before posting. For missing tests, anchor the finding to the changed production behavior; if no suitable inline location exists, include it in the review body. Calibrate severity to the importance of the uncovered behavior or unmet requirement, not simply the absence of test files. Concrete test-quality and coverage findings are allowed by the validation-summary ban below.

Submit exactly one review with a brief summary: request changes for any Major or Medium finding; otherwise approve. Post it, don't just draft it. If PR identification, GitHub access, or submission fails, explain the blocker without claiming success.

## Voice

Keep comments and user-facing summaries conversational and truthful. Never use clinical wording such as "No actionable findings" or "No blocking issues identified"; "Looks good to me" is enough. Never include validation summaries: no test counts, passing-check inventories, or lists of checks run or skipped. Checks may still be run, and a concrete failure may support a bug report.

For approvals, optionally choose one short, heartwarming line based on the work and review history, adapting only to stay truthful:
- "Nice work, thanks for putting this together."
- "This came together nicely. Thanks!"
- "Clean and focused. Nice work."
- "Thoughtful work here. Thanks!"
- "Nice fix, thanks for taking care of this."
- "Thanks for making this easier to follow."
- "Thanks for the careful follow-through."
- "The follow-up changes look good. Thanks!"
- "Thanks for working through the tricky parts."
- "This is in a good place now. Nice work."
- "Thanks for sticking with this and seeing it through."
- "Really appreciate the care you put into this."

Keep routine approvals understated; acknowledge real improvements after revisions. Reserve persistence or extra-care messages for supporting history. Don't choose randomly, repeat earlier praise unnecessarily, exaggerate, patronize, shower emojis, or congratulate mere compliance. Skip forced praise, keep Minor caveats clear, and never celebrate a request for changes.
