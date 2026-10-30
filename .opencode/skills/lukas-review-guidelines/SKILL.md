---
name: Lukas Review Guidelines
description: Reusable architecture, test-scrutiny, and writing guidance for reviewing pull requests in Lukas's style.
---

# Lukas Review Guidelines

Load this when conducting a pull-request review or drafting technical review feedback.

## Prepare context

- Read the target repository's applicable `AGENTS.md` files and testing guidance. Repository instructions take precedence over these preferences.
- Read `~/dotfiles/docs/software-architecture-rules.md` and load `@lukas-voice`. Use the architecture rules to guide technical assessment and the voice skill for review comments and user-facing summaries.
- Search for testing guidance by filename and content: `TESTING.md`, test-strategy documents, `CONTRIBUTING.md`, README testing sections, and docs or package-local guidance. Follow relevant references and read what applies to the changed code. If no strategy is found, use repository instructions, existing test conventions, and CI configuration as evidence; distinguish inferred conventions from explicit requirements.

## Test scrutiny

Evaluate test adequacy for every behavior change, even when the PR contains no test files. Hold tests to the project's documented standards for test layers, isolation, fixtures, mocking, assertions, determinism, regression coverage, and duplication. Passing CI and test counts do not establish adequate coverage.

- Map changed behavior and failure modes to concrete existing or added tests. Read relevant tests beyond the diff. For bug fixes, check whether a regression test would fail on the original defect and pass with the fix.
- Assess whether tests exercise production behavior and assert meaningful observable outcomes. Look for assertions that merely mirror implementation, mocks that bypass the behavior under review, happy-path-only coverage where important failures changed, brittle implementation coupling, and uncontrolled time, randomness, shared state, or external dependencies. Tie criticism to concrete consequences and project standards, not personal preference.
- Compare added and changed scenarios with each other and existing tests for duplicate behavioral coverage. Consider merging redundant scenarios or using table-driven/parameterized cases when setup, execution, and assertions are substantially the same. Explain the overlap and propose a concrete consolidation that preserves distinct boundaries, failure modes, readability, and useful failure diagnostics. Follow project conventions; don't merge unrelated behaviors merely because their test code looks similar. Treat worthwhile consolidation as a Minor improvement unless evidence supports greater severity.
- When no tests are submitted, investigate whether existing tests cover the changed behavior and whether the project requires new coverage. Assess any rationale for omitting tests against the strategy and actual change. Don't assume omission is acceptable because the implementation looks correct or CI passes; don't demand redundant tests for behavior already adequately covered or exempted by project guidance.
- Report missing or weak tests as actionable findings when they leave meaningful changed behavior unprotected or violate an applicable testing requirement. Identify the uncovered scenario, cite the standard when available, and propose the appropriate test layer and observable assertion. A test finding doesn't require proving a production bug already exists.

## Review writing

- Lead with the finding or decision. Be concise, direct, conversational, and specific; explain the practical consequence and propose a concrete alternative where useful.
- Keep comments truthful and calibrated to the evidence. Don't invent history, certainty, test results, approval, or commitments. Avoid generic/formulaic wording and clinical summaries such as “No actionable findings”; “Looks good to me” can be enough.
- Put identifiers, paths, and literal values in backticks. Use structure only when it clarifies multiple independent points or a substantial explanation.
- Follow `@lukas-voice` for tone and final checks.
