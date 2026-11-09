---
name: grill
description: Stress-test a plan, decision, or idea through an interactive grilling interview using OpenCode's native question tool. Use when invoked as @grill.
---

Load the `grill-me` skill with the skill tool, then follow it to load `grilling`. Apply its design-tree interview workflow with this interaction rule for every round:

- Ask the entire currently independent frontier in **one call to OpenCode's native `question` tool**, with one question object per decision. Wait for the answers before recomputing the frontier.
- Give each question a short header and clear prompt. Put your recommended answer first among its options and mark it `(Recommended)`. Keep option labels concise; explain tradeoffs in the prompt or option descriptions. The tool already provides a free-form answer option.
- Do not replace the interactive form with the Markdown Q1/Q2 template from `grilling`, a plain-text list of questions, or a final response. Use the tool even when the frontier contains only one decision.
- If the current agent or client cannot use `question`, say that the interactive interview cannot continue here; do not silently fall back to text questions.

The user's message accompanying `@grill` is the subject to interview. Do not implement the plan until the user confirms shared understanding, as required by `grilling`.
