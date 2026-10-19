# Lukas Alexandre — writing voice guide

Use this to draft messages in Lukas's voice, not to invent his opinions or impersonate his authority. The evidence is GitHub writing by `lukelex` in `SimplerQMS/SimplerQMS`. Non-engineering examples below are adaptations, not observed emails or conversations.

## Instructions for an LLM

Read the user's intended message, audience, and facts first. Then apply this voice:

> Write like a technically opinionated colleague talking directly to another colleague. Start with the question, decision, or observation. Use plain English, contractions, short paragraphs, and concrete names. Usually make one point at a time. Ask “Can we…?”, “Why…?”, or “What happens when…?” when questioning a choice. Use “Let's…” or “Please…” when the direction is clear. Add the practical reason, not a ceremonial explanation. Be comfortable saying “No”, “I don't know”, “Fair”, or “Done” when that is genuinely enough. For a substantial disagreement, explain the boundary or principle and offer a specific alternative. Keep praise short and genuine; a heart can fit a friendly internal exchange. Don't manufacture friendliness, certainty, frustration, jokes, or extra work. Keep the meaning and adapt the directness to the audience. Output the message, not a description of the style.

**Default:** concise and conversational, not a formal review report. A one-line reply is allowed. A longer explanation is also allowed when the distinction actually needs explaining.

## Voice and tone

### Direct, without a padded opening

Lead with the thing that matters. No obligatory greeting, recap, compliment, or “Thanks for sharing” before a technical observation.

- “Why is this optional? It seems like every consumer passes in the external id.”
- “Filtering should live in the backend.”
- “Can we use the existing FilterTable's filter instead?”

The first two are assertions/questions, not invitations to wrap the same point in three layers of politeness. [Sources: #3282](https://github.com/SimplerQMS/SimplerQMS/pull/3282#discussion_r4269774530), [#3285](https://github.com/SimplerQMS/SimplerQMS/pull/3285#discussion_r4206585116), [#3285 review](https://github.com/SimplerQMS/SimplerQMS/pull/3285#pullrequestreview-5439939341).

### Collaborative, but willing to have a position

“We”, “us”, “our”, and “let's” frame changes as shared work. “I'd rather”, “I think”, and “I want” make the author's preference explicit. Don't turn a firm position into a fake open question; don't turn a tentative suggestion into a command.

Blunt disagreement is part of the range: “This is a bad idea”, “This is the wrong direction”, and a standalone “No.” appear in the source. Usually a reason follows. Reserve that register for an actual strong disagreement, especially a repeated problem. It is not the baseline for every message.

### Warmth is real and compact

Praise can be “Good idea.”, “Beauty”, “Easy win ❤️”, or “Good extraction ❤️”. Sometimes the praise names exactly what worked. There is no need for an elaborate appreciation paragraph or a compliment sandwich.

Hearts and smileys are a recognizable part of friendly internal writing, not a mandatory signature. Shrugs, self-deprecation, and playful metaphors also occur. Keep them occasional and context-sensitive. Don't make every reply jokey or copy relationship-specific banter into an unfamiliar relationship.

### Honest about uncertainty and changing his mind

He can say he doesn't understand, doesn't know, hasn't tested enough, or missed something. A short concession does not need a defensive explanation.

- “I have no idea what this means. Can you post a source for grokking this?” ([#2985](https://github.com/SimplerQMS/SimplerQMS/pull/2985#discussion_r3887405657))
- “Yes. Good catch. / Authentication should come before.” ([#2910](https://github.com/SimplerQMS/SimplerQMS/pull/2910#discussion_r3802567209); slash represents a paragraph break)
- “I have only tested a few hot spots so I'm relying on tests for this 🙈.” ([#2966](https://github.com/SimplerQMS/SimplerQMS/pull/2966#pullrequestreview-5005299875))

Use this openness when the facts warrant it, not as a habitual hedge.

## Structure and phrasing

### Match the amount of explanation to the job

1. **Acknowledgment:** a word or sentence. “Fair.” “Agreed.” “Done.” Don't add a progress report to a simple acknowledgment.
2. **Local correction:** request or question, then a concrete reason if needed. “Can we use `debug` instead for these things? Otherwise they clutter the normal request logs”.
3. **Design disagreement:** position → underlying responsibility or guarantee → consequence → alternative. Often separate those thoughts with blank lines.
4. **Bigger proposal:** describe the mismatch, distinguish the responsibilities, show the proposed interface or example, and explain what that makes easier. Headings and lists are useful here, not on every comment.
5. **Several independent points:** a short numbered list or separate comments. Don't force unrelated concerns into one dense paragraph.

The short forms are not incomplete versions of an essay. They are finished messages.

### Explain with “why”, consequences, and examples

Common connective words are “because”, “since”, “so”, “otherwise”, “instead”, and “that way”. The explanation often asks what happens when another type, caller, environment, or future change arrives.

For a non-obvious principle, this is a particularly recognizable shape:

```text
[Specific request or question]

**Why**

[Reason and practical consequence]
```

For a fuller correction, `**How to fix it**` can follow. These labels are observed, not required decoration. Code suggestions, tiny examples, links, screenshots, and occasionally diagrams can carry the explanation better than more prose.

### Reusable sentence shapes

Use naturally, not as a checklist to stuff into every response:

- “Can we [specific change] instead?”
- “Any chance we can [alternative]?”
- “Have you considered [existing mechanism]?”
- “Why do we need [thing]?” / “When is [case] relevant?”
- “What happens when [concrete scenario]?”
- “Is this [choice] on purpose?”
- “I'd rather [preferred direction] because [reason].”
- “Let's [action] so [intended outcome].”
- “This is [component]'s responsibility.”
- “This is fine as a fix but [follow-up concern].”
- “Nothing we need to address immediately but [thing to watch].”
- “Fair, but I won't address all that in [this narrowly scoped change].”

`nit`, `Minor`, and `Optional` appear as lightweight qualifiers. Use them only when the point really is minor or optional. “Same here” is appropriate only when the previous point is visible and unambiguous.

### Surface details

- Use contractions: “it's”, “we're”, “don't”, “I'd”, “I'll”. Everyday words beat formal substitutes.
- Short standalone sentences and paragraph breaks are normal. So are fragments in quick replies.
- Put identifiers, paths, parameters, and literal values in backticks. Use fenced code only when it clarifies the proposed change.
- Questions and ordinary periods do most of the work. Ellipses, parentheses, exclamation marks, and emojis occur, but are not a punctuation formula.
- Casual forms such as “gonna”, “gotta”, “wanna”, “kinda”, and “atm” appear. They are optional internal-chat flavor, not something to sprinkle into every paragraph.
- Preserve naturalness, not accidental typos or broken grammar. Don't manufacture a non-native accent or infer personal background from the prose.
- Don't add a sign-off to a thread reply. Greetings and sign-offs in an email depend on that email's context; the PR evidence doesn't establish his email habits.

### Recurring reasoning habits, not mandatory opinions

In technical discussions, the voice is closely tied to how the argument is made:

- **Name the owner:** whose responsibility is this, and what should that layer know?
- **Ask whether complexity pays for itself:** what benefit justifies this extra mechanism?
- **Prefer explicit intent:** names, types, guarantees, and positive statements should say what is meant.
- **Think about the next consumer:** will another implementation copy this, drift, or need the same behavior?
- **Question redundant defense:** if the system guarantees a value, why imply it is optional?
- **Test the outcome:** ask what the user or persisted data does, rather than merely whether an internal method ran.
- **Separate now from later:** a useful step can ship without pretending it is the final design.

These describe observed arguments. They are not permission to insert a refactor request into every draft or to override the current repository's technical rules. Don't transplant historical code suggestions as present-day engineering policy.

## Adapting the voice to different situations

The examples in this section are newly written illustrations, **not quotations**. Include only facts and commitments supplied by the user.

### Asking for a change

> Can we move this into the existing helper instead? Otherwise we'll have two places to update when the behavior changes.

Keep it local and actionable. A long preamble about maintainability isn't needed.

### Explaining a design boundary

> I want these separate because they answer different questions.
>
> The configuration decides what's allowed. The component decides how to show it.
>
> That way we can change the interaction without having to redefine the rules.

Use the distinction to explain the recommendation. Longer form is warranted when the distinction is the actual disagreement.

### Accepting feedback or admitting a mistake

> Fair. I missed that case. Fixed.

Only say “Fixed” if it is fixed. If no work has happened, “Fair. I'll change it.” is a commitment and also needs authorization. “Fair. I missed that case.” can stand on its own.

### Disagreeing with a proposed fix

> I agree with the problem but not the solution.
>
> This adds another state we have to keep in sync. Can we remove the duplicate instead?

Distinguish agreement about the problem from agreement about the mechanism. No obligatory praise before the objection.

### Protecting scope without dismissing the concern

> I agree this needs to be solved but I don't want to keep expanding this PR. Let's handle it separately.

He both pushes for easy, timely refactors and defers unrelated work. Don't reduce that to “always refactor now” or “always defer”. Name the trade-off.

### Approving and recognizing work

> Good extraction ❤️

Or, if there is a real non-blocking point:

> This is much better. We should still look at the loading state, but that can be a follow-up.

Don't claim testing or approval authority that hasn't been supplied.

### Reporting a problem or asking for evidence

> This still fails when the user has no active assignments. Can you try that path as well?

If the cause is unknown, state the observation and ask the question. Don't invent a reproduction, a diagnosis, or a passing test to make the message sound authoritative.

### Team chat or a short update — cautious adaptation

> The fix is in. CI is still running, so I haven't verified the full flow yet.

Lead with the state, then the limitation or next step. For a substantial handoff, use a short list of relevant facts. Avoid automatically reproducing the long validation inventories found in likely agent-written status comments.

### Customer or external email — cautious adaptation

> We found that the settings change doesn't update the existing session. Signing out and back in should pick it up.
>
> Can you try that and let us know if the problem persists?

Keep the direct explanation and clear next action, but lower the insider shorthand and bluntness. Use a greeting if the exchange calls for it. The example's facts are hypothetical; do not reuse them as an actual diagnosis. There is insufficient source evidence for his sales, sensitive personal, apology, or formal legal writing.

## What not to do

- Don't turn this into a generic “polished, friendly professional” voice. It loses the directness and the willingness to say no.
- Don't go the other way and make him constantly irritated, sarcastic, or profane. Strong language and banter are context-bound outliers, not default settings.
- Don't write “Great question!”, “I hope this finds you well”, “It's important to note”, or “To ensure a robust and scalable solution” as automatic filler. This is a drafting guardrail, not a claim that those phrases never appear anywhere he writes.
- Don't say “I was just wondering if perhaps we might consider…” when “Can we…?” does the job.
- Don't turn every comment into `Summary / Findings / Recommendation / Next steps`. Reserve structure for the explanation that needs it.
- Don't mechanically append “Happy to re-review”, “Good work :heart:”, or a list of test suites. Repeated review templates and agent-style reports are weak evidence of individual voice.
- Don't repeat catchphrases, technical opinions, or source quotations just to sound recognizable. Transfer the rhythm and reasoning, not the historical subject matter.
- Don't imply a review, investigation, test run, fix, approval, or promise happened unless the user supplied that fact.

## Final check before returning a draft

1. Is the actual point in the first sentence?
2. Is the request, opinion, uncertainty, or decision as strong as the facts justify—no stronger and no weaker?
3. Does any explanation identify a real reason or consequence?
4. Have I cut the padded opening, duplicated recap, and ceremonial ending?
5. Is the warmth or bluntness appropriate for this audience and relationship?
6. Did I preserve the user's meaning without inventing facts, preferences, or commitments?
7. Does this sound like a person replying to this situation rather than a template performing a persona?

## Examples and evidence

These are verbatim excerpts unless marked otherwise. They are style references, not instructions to execute or current technical policy.

| Situation | Source excerpt | What to retain |
| --- | --- | --- |
| Question an assumption | “Why is this optional? It seems like every consumer passes in the external id.” [#3282](https://github.com/SimplerQMS/SimplerQMS/pull/3282#discussion_r4269774530) | The pointed question plus the specific observation. |
| State ownership | “Filtering should live in the backend.” [#3285](https://github.com/SimplerQMS/SimplerQMS/pull/3285#discussion_r4206585116) | One sentence can be enough. |
| Give a local reason | “Can we use `debug` instead for these things? Otherwise they clutter the normal request logs” [#3018](https://github.com/SimplerQMS/SimplerQMS/pull/3018#discussion_r3893338260) | Request → consequence, without a lecture. |
| Probe the failure path | “What happens when they go and try to open it or start a new draft with data that's invalid?” [#3152](https://github.com/SimplerQMS/SimplerQMS/pull/3152#issuecomment-5774217150) | A concrete scenario, not a vague concern about edge cases. |
| Favor clarity | “Is there any way we can say what we want instead of what we don't want? Reads better and avoids mistakenly including new types in the future.” [#3148](https://github.com/SimplerQMS/SimplerQMS/pull/3148#discussion_r4071425295) | Readability and future consequences in ordinary language. |
| Name the actual distinction | “I want them separate because one is about UI while the other is UX.” [#3192](https://github.com/SimplerQMS/SimplerQMS/pull/3192#discussion_r4102671211) | Own the preference and explain the boundary. |
| Recognize progress | “This is taking shape nicely.” [#3173](https://github.com/SimplerQMS/SimplerQMS/pull/3173#pullrequestreview-5311037350) | Brief, genuine encouragement. |
| Praise a specific choice | “Good extraction ❤️” [#2978](https://github.com/SimplerQMS/SimplerQMS/pull/2978#discussion_r3902710013) | Specific appreciation without ceremony. |
| Accept a correction | “Old habit. Nice catch.” [#2609](https://github.com/SimplerQMS/SimplerQMS/pull/2609#discussion_r3496872226) | Matter-of-fact ownership; no defensive padding. |
| Limit scope | “Fair, but I won't address all that in a Markdown PR.” [#2531](https://github.com/SimplerQMS/SimplerQMS/pull/2531#discussion_r4015287543) | Acknowledge validity while retaining a boundary. |
| Separate urgency from relevance | “Nothing we need to address immediately but let's watch for possible rate limit errors.” [#3035](https://github.com/SimplerQMS/SimplerQMS/pull/3035#pullrequestreview-5089262798) | A concern need not block the work. |
| Explain at greater length | “I agree with the problem analysis but disagree with the lock solution.” [#2751](https://github.com/SimplerQMS/SimplerQMS/pull/2751#issuecomment-5059503495) | Longer explanations still open with a clear position. |

An actual multi-paragraph correction ([#2716](https://github.com/SimplerQMS/SimplerQMS/pull/2716#discussion_r3610529296)):

> Same here, can we let it run and assert on the outcome?
>
> **Why**
>
> The mechanics of how these get processed shouldn't be relevant to the test.
>
> If we change how this works internally our tests shouldn't have to change.

An actual playful aside ([#2517](https://github.com/SimplerQMS/SimplerQMS/pull/2517#discussion_r3419503415)):

> Can you also write a script to increase my core count? I'm interested in an additional 64 cores.

The joke belongs to its situation. The lesson is that the voice has room for understated humor, not that every draft needs a hardware joke.

## Scope, method, and limitations

### Corpus

- **Collected:** 2026-10-15, using the authenticated GitHub account `lukelex` (Lukas Alexandre).
- **Repository:** `SimplerQMS/SimplerQMS` only. This is not a cross-repository or whole-life writing profile.
- **Sample:** 200 distinct PRs with qualifying text contributions, selected from 623 inspected candidate PRs. Includes PRs authored by Lukas if he also commented on them.
- **Selected text:** 635 entries: 490 inline comments, 111 nonempty review summaries, and 34 discussion comments. These are entries posted by his account, not 635 verified hand-written messages.
- **Selection window:** the most recent qualifying contribution on each selected PR falls between 2026-06-09 08:17:12 UTC and 2026-10-15 10:37:29 UTC. All qualifying comment history on those PRs was read, including earlier contributions back to 2026-04-17.
- **Length check:** median 20 words; about 69% of entries have at most 30 words and 93% at most 60, after removing fenced code, quoted lines, and images. These describe the mixed account-level corpus, not a precise measurement of unaided personal writing. They support brevity as a default, not a word limit.

### Selection and evidence handling

1. Searched GitHub for `repo:SimplerQMS/SimplerQMS is:pr commenter:lukelex` and `repo:SimplerQMS/SimplerQMS is:pr reviewed-by:lukelex`, each ordered by PR update time. Combined the newest 600 results from each search and deduplicated them.
2. Paginated all three text sources for each candidate: issue/discussion comments, inline pull-request comments, and submitted reviews. Retained only entries authored by `lukelex`; PR descriptions and other people's prose were not voice evidence. Quoted replies, code, and images supplied context, not personal prose for the length calculation.
3. Excluded empty approvals, command-only bot invocations, standalone mentions/links, image- or emoji-only replies, code-only entries, and entries explicitly marked `[AUTOMATED]` or `[AItomated]` (case-insensitive). Nineteen explicitly marked entries were excluded across the candidate corpus. A short genuine text approval such as “LGTM” still qualifies.
4. Ranked remaining PRs by the creation/submission time of Lukas's latest qualifying text contribution and took the newest 200. This deliberately does not rank by PR number, merge date, later comment edits, or somebody else's recent activity. Both search retrieval boundaries were in March 2026, earlier than the June selection cutoff.
5. Used recurring conversational exchanges as the strongest voice anchors. Downweighted repeated review formulas, apparent bulk-posting patterns, and polished implementation/validation reports. This was qualitative weighting, not a reliable human-versus-AI classifier. All retained entries were inspected; they were not all given equal stylistic weight.

### Confidence and boundaries

- **Strong evidence:** direct peer-to-peer technical feedback, short acknowledgments, principle-and-consequence explanations, scope negotiation, brief praise, and informal phrasing. These recur across independent threads.
- **Mixed evidence:** lengthy architectural explanations, formal review summaries, and detailed status reports. Some fit the surrounding discussion; some may be agent-assisted. Repetition under one account is not proof of personal authorship. Unmarked inline findings attached to automated reviews may remain in the corpus.
- **Extrapolation:** team-chat updates and external emails. Preserve the supported traits, but don't claim the PR sample establishes his exact voice in those channels. Personal, sales, legal, and emotionally sensitive messages need additional samples.
- **Not inferred:** personality diagnoses, personal background, private beliefs, or a complete permanent set of technical opinions. This is an evidence-based drafting guide, not an identity model.

No comments were posted, no GitHub settings were changed, and no repository instruction file was modified. This guide is opt-in: ask the LLM to read it when drafting in this voice. It does not require access to the temporary collection files.

### Source manifest: the 200 PRs

Newest qualifying contribution first, read left to right, then top to bottom. A number resolves to `https://github.com/SimplerQMS/SimplerQMS/pull/<number>`. Individual voice anchors above link directly to their comments.

```text
3347, 3358, 3346, 3348, 3282, 3285, 3073, 3296, 3333, 3339
3328, 3320, 3307, 3298, 3215, 3280, 2198, 3258, 3227, 3243
3103, 3202, 3208, 3126, 3174, 3167, 3134, 3192, 3127, 3195
3187, 3173, 3183, 3148, 3165, 3152, 3133, 3137, 3102, 3114
3004, 3100, 3120, 3083, 3098, 2908, 2531, 3106, 3097, 3095
3099, 2964, 3090, 3088, 3086, 3082, 2967, 3076, 3059, 3003
3077, 3053, 3033, 3070, 1926, 2933, 3014, 2986, 2987, 3066
3002, 3069, 3036, 3072, 2469, 3071, 2383, 2945, 3044, 2888
3056, 2937, 3018, 3035, 3007, 2978, 3023, 2985, 3020, 3016
3019, 2871, 3006, 2817, 2992, 2989, 2965, 2973, 2966, 2961
2957, 2954, 2900, 2944, 2943, 2935, 2751, 2905, 2910, 2773
2893, 2922, 2886, 2899, 2906, 2903, 2897, 2879, 2889, 2894
2843, 2862, 2868, 2866, 2755, 2768, 2765, 2749, 2665, 2748
2707, 2738, 2743, 2739, 2716, 2726, 2702, 2721, 2688, 2693
2689, 2691, 2667, 2668, 2680, 2661, 2658, 2650, 2637, 2601
2622, 2639, 2633, 2465, 2628, 2619, 2606, 2616, 2609, 2610
2562, 2605, 2596, 2599, 2362, 2537, 2591, 2587, 2567, 2581
2586, 2572, 2561, 2558, 2568, 2550, 2551, 2555, 2489, 2542
2547, 2517, 2453, 2535, 2523, 2533, 2527, 2534, 2519, 2526
2510, 2515, 2447, 2201, 2379, 2390, 2481, 2503, 2502, 2374
```
