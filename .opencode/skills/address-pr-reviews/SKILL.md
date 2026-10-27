---
name: Address PR reviews
description: Triage and implement worthwhile review feedback on a pull request, then resolve comments that have actually been addressed.
---

# Address PR reviews

When asked to handle review feedback on a pull request:

1. Read `~/dotfiles/docs/LUKAS_WRITING_STYLE.md` before drafting any replies. Use its concise, direct, friendly guidance; don't imitate source examples mechanically or claim work that hasn't happened.
2. Identify the PR from the supplied URL. Inspect the repository state and its instructions before editing. Confirm the current branch/worktree corresponds to the PR; do not switch branches or make unrelated changes without authorization.
3. Fetch all review feedback, including inline review threads, submitted reviews, and general PR discussion. Include unresolved threads and relevant context/replies. Do not assume every comment is actionable or addressed to the PR author.
4. Triage each point on its merits. Implement concrete, relevant fixes that fit the PR's intent and repository conventions. Skip praise, questions already answered, obsolete feedback, suggestions that are not worthwhile, and issues outside the PR's scope. For ambiguous or consequential tradeoffs, ask the user before deciding. Do not silently broaden the work.
5. Make the changes and run the most relevant available tests/checks. Be explicit about anything not verified. Review the diff to ensure it only addresses accepted feedback.
6. Resolve only the review threads whose actionable concern is fully addressed by the code change or an already-satisfactory explanation. Do not resolve comments merely because they were read, nor comments declined/deferred. Use the available GitHub integration to resolve threads; if it cannot do so, report that instead of implying they were resolved.
7. For each resolved thread, reply with a short, friendly explanation in the style from `~/dotfiles/docs/LUKAS_WRITING_STYLE.md`. State what changed (or the concrete reason the concern was already satisfied). Keep it specific and truthful; avoid a generic thank-you, test claims you didn't verify, or promises of future work. A concise “Fair. Fixed.” is fine when accurate.
8. Summarize what was changed, which feedback was intentionally left unaddressed and why, validation performed, and any comments that could not be resolved/replied to.

Never post a reply or resolve a thread until the corresponding work/status is confirmed. Treat GitHub actions that publish comments or resolve threads as external side effects, and perform them only for feedback actually addressed as requested.
