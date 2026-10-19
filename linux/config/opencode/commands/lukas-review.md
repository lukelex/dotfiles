---
description: Review the current GitHub PR and submit a review
---

Review the GitHub pull request for this branch and submit your findings on the PR. Use any supplied PR number or URL. $ARGUMENTS

Before reviewing, read the applicable `AGENTS.md` files for the repository and the directories touched by the PR, `~/dotfiles/docs/LUKAS_WRITING_STYLE.md`, and `~/dotfiles/docs/software-architecture-rules.md`. Follow repository instructions and documentation first. Use the architecture preferences as additional review guidance only where they don't conflict with repository documentation; if they do conflict, follow the repository documentation. Use the writing guide for review comments and the review summary: keep them direct, concise, conversational, and grounded in concrete consequences. Do not imitate or invent opinions, and don't claim tests or checks ran unless they did.

Find the PR from the current branch unless the arguments identify a PR number or URL. Inspect the PR description, complete diff, and relevant surrounding code before deciding. Check for correctness issues, regressions, security problems, and missing tests. Report only actionable findings introduced by this PR; don't report style preferences or speculative risks as defects.

Read the PR's previous reviews, discussion, and changes since the last review, when available. Verify whether earlier concerns were actually addressed rather than relying on resolved threads alone. Use that history to understand how the PR has evolved and choose an appropriate reaction; don't invent a review history or imply you previously reviewed it if you didn't. Still review the complete current diff, not just the latest changes.

Classify each finding internally:
- **Major**: likely causes serious data loss, security exposure, broad outage, or a core workflow becoming unusable.
- **Medium**: a real bug or regression that affects a meaningful case and should be fixed before merging.
- **Minor**: a limited or non-blocking issue, edge case, or improvement.

For every finding, provide the severity, a short title, a precise file and line range in the PR diff, what can go wrong, and a concrete proposed fix. Verify that the cited lines are in the diff. Include the proposed change in the corresponding PR comment: use a GitHub `suggestion` block when the fix is a precise replacement for the selected lines; otherwise include a concise fenced code block that illustrates the concept. The code must fit the surrounding implementation and repository rules. Don't invent missing APIs or unrelated refactors. Avoid duplicate findings. If there's nothing to flag, keep the approval brief and natural, such as "Looks good to me." Never use clinical review jargon such as "No actionable findings" or "No blocking issues identified" in posted reviews or user-facing summaries.

Submit a GitHub pull request review with inline comments for findings where the platform supports them, and a concise summary. Request changes if at least one finding is Major or Medium. Approve if all findings are Minor or there are no findings. Do not merely print a proposed review: post it. If the PR cannot be identified, GitHub access is unavailable, or review submission fails, explain the blocker and do not claim the review was submitted. Do not modify the PR branch.

Never include validation summaries in posted reviews, inline comments, or user-facing summaries: no test counts, passing-check inventories, or lists of checks you ran or didn't run. This does not prevent running checks or reporting a concrete failure as evidence for a specific bug; explain the bug and its consequence rather than giving a testing status report.

For approvals, add at most one short, heartwarming line when it fits. Be warm and genuine, not effusive or patronizing: no grand praise, emoji showers, or congratulations merely for complying with feedback. Choose from these examples based on the actual work and review history, adapting lightly to stay truthful:
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

Match the warmth to the context: keep routine first-pass approvals understated; acknowledge specific improvements after revisions; reserve persistence or extra-care messages for history that supports them. Don't pick randomly or repeat the same praise from an earlier review when another line fits better. If congratulations would feel forced, skip them and give a neutral, brief approval. Keep any remaining Minor findings clear; warmth must not obscure caveats or change the approval criteria. Never add a celebratory line to a request for changes.
