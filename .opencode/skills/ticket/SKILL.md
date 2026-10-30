---
name: ticket
description: Implement or review work from a Linear issue or GitHub pull request, following repository architecture and writing guidance.
---

# Work from Linear or PR

Use this skill when the user provides a Linear ticket or GitHub pull request link and asks you to work from it. Treat the link as the task context; do not assume permission to publish comments, change ticket status, merge, or otherwise make external changes unless the user asks.

## Guiding documents

1. Read `~/dotfiles/docs/software-architecture-rules.md` before making design decisions. Apply its principles to code organization, responsibility boundaries, abstractions, failure behavior, and tests. Treat these as guiding principles, not a reason to expand scope.
2. Read `~/dotfiles/docs/LUKAS_WRITING_STYLE.md` before drafting or editing any text on Linear or GitHub. Preserve the user's meaning and facts; write directly and concisely without inventing opinions, status, test results, or commitments.
3. Inspect the target repository's `AGENTS.md` and any more specific `AGENTS.md` files governing the files you will touch. Follow those instructions alongside the repository's existing conventions and validation guidance. If instructions conflict, honor the more specific applicable repository guidance and explain material conflicts.

## Workflow

1. Identify whether the link is a Linear issue or GitHub PR. Retrieve its description and relevant discussion/review context. If the link is inaccessible or ambiguous, ask for the missing context rather than guessing.
2. Before editing, ask the user whether the work should be done on the current branch or in a worktree. Then inspect `git status`, the current branch, and existing changes in the chosen working tree. For a PR, confirm the checkout/worktree is the relevant one; don't switch branches or overwrite unrelated user changes. If the requested choice would risk existing changes or the correct PR worktree is unavailable, explain the issue and ask how to proceed.
3. Check whether the working branch contains commits or changes that are not on `main` (or the repository's designated base branch). If it does, show the user what is ahead and ask whether those commits/changes should be included in the PR or whether the PR should contain only work related to this ticket. Don't rebase, reset, cherry-pick, or otherwise alter that history until the user chooses. If the base branch is unclear, ask or follow the repository's documented default.
4. Read the guiding documents and repository instructions above. Explore the relevant code and tests, then translate the ticket/PR intent into a narrow, concrete change. Ask before making consequential assumptions or broadening scope.
5. Implement the change in the repository's established style. Keep decisions with the component that has the necessary context, prefer clear domain-specific behavior over premature generalization, account for failure paths and operational effects, and test observable behavior where practical.
6. Run relevant checks specified by repository instructions and the project. Inspect the final diff and status to ensure changes are limited to the requested work. Report checks that were not run or did not pass accurately.
7. If the task requires writing or updating a Linear/GitHub description, comment, review, or other published text, apply the writing guide and verify every factual claim. Publishing is an external side effect: do it only when explicitly requested, and only after verifying the code/work status. Never imply a comment was posted, a thread resolved, or a ticket updated unless confirmed.
8. Summarize the change, validation, and any unresolved questions or limitations. Keep the summary concise and factual.

## Guardrails

- A link alone does not authorize posting, resolving review threads, changing issue state, creating commits, or merging.
- For PR feedback, assess each point on its merits; address relevant actionable feedback and leave unrelated, obsolete, or already-satisfied points alone. Do not claim a concern is resolved without evidence.
- Don't claim tests, builds, deployments, or external actions succeeded unless you observed that result.
- Keep the work scoped to the request. When ambiguity affects behavior, architecture, or public communication, ask the user before deciding.
