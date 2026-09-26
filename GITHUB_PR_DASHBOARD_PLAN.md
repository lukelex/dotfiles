# GitHub PR Dashboard Plan

## Status

This is a proposal for a future cross-platform application, not a description
of the current desktop implementation. Today, Quickshell's
`linux/config/quickshell/GitHubReviewCenter.qml` displays PRs from
`GitHubPrService.qml` and `linux/config/quickshell/scripts/github-prs`; a
separate `linux/config/github-review-notify/github-review-notify.timer` runs
`linux/scripts/github-review-notify` for review notifications. The shared
cross-platform core, PR-level read/snooze state, and macOS/Windows applications
below are still proposed.

## Decision

Build this as a cross-platform native application with a platform-neutral core.
The existing Quickshell panel should become a Linux integration surface, not
the product boundary.

The app must eventually support macOS and Windows, where Quickshell is not
available. A native application can provide a consistent dashboard, local state,
and GitHub data model across platforms, while platform adapters provide:

- Linux: Quickshell bar entry, panel launcher, and native notifications.
- macOS: menu-bar entry and native notifications.
- Windows: tray entry and native notifications.

The core should own GitHub retrieval, prioritisation, acknowledgement, snoozing,
and event transitions. Platform adapters must not duplicate that state.

## Product goal

Provide an actionable PR workspace that answers:

1. Do I need to review something?
2. Has someone reviewed or commented on one of my PRs?
3. What is the health and next action for PRs I own or follow?

This is an action queue, not a generic notification history.

## Default view: Tailored to you

Rank PRs in these bands, newest meaningful event first inside each band:

1. Review requested from me.
2. My PRs requiring action:
   - changes requested;
   - new reviewer activity since acknowledgement;
   - failing CI;
   - merge conflicts or blocked mergeability;
   - approved and ready to merge.
3. My PRs awaiting review.
4. PRs I follow, ordered by recent activity.
5. PRs closed or merged in the previous 14 days.

## Views

The dashboard supports:

- **Tailored to you**: default ranked action queue.
- **Action**: PRs needing attention only.
- **My PRs**: authored PR health and status.
- **Following**: involved PRs not authored by me.
- **Recent**: closed and merged PRs from the previous 14 days.

## PR presentation

### Collapsed PR parent

Every parent card shows:

- repository and PR number;
- two-line title;
- lifecycle state: open, draft, closed, merged;
- concise health state: review decision, CI, mergeability;
- action label;
- latest relevant event and relative age, for example `Changes requested · 2h ago`.

### Expanded event timeline

Expanding a parent shows chronological child events, such as:

```text
Reviewed by Alice · CHANGES_REQUESTED · 28m ago
Requested updates to validation handling.

CI failed · 3h ago
test / integration failed.
```

Child events include reviews, review comments, review requests, check changes,
and merge-state changes.

## Actions

Each PR exposes:

- Open in browser (PR conversation).
- Start review (Files changed).
- Mark read.
- Snooze: later today, tomorrow, or next week.
- Copy link.

Mark-read and snooze state are local to the device. A new relevant event must
reactivate the PR.

## Data architecture

```text
GitHub API / GitHub CLI
  -> cross-platform dashboard core
  -> local state and event transition engine
  -> native application UI
  -> platform adapters (Quickshell, macOS, Windows)
```

The core retrieves and normalises:

- PR identity, title, URL, author, repository, and lifecycle state;
- authored/review-requested/involved relationship;
- review decision, reviewer requests, reviews, and review comments;
- check status and mergeability;
- latest meaningful activity;
- recent closed and merged PRs.

Persist dashboard state independently from generic desktop notification history:

```text
github-pr-dashboard.json
```

It tracks read-event watermarks, snooze expiry, event fingerprints, and the last
attention state used for deduplicated desktop notifications.

## Refresh and notification policy

- Refresh when the dashboard opens.
- Refresh every five minutes while running.
- Support manual refresh and clear loading, stale, and error states.
- Support github.com in version one.

Send an interruptive native notification only when a PR newly needs attention:

- a review is requested from me;
- a new review/comment arrives on my PR;
- changes are requested on my PR;
- CI fails on my PR;
- a merge conflict or blocked merge state appears on my PR.

## Delivery phases

### 1. API and domain spike

Define bounded GitHub queries for review requests, authored PRs, involved PRs,
reviews/comments, checks, mergeability, and recent completions. Define a stable
event fingerprint and verify rate-limit behavior.

**Exit:** a validated snapshot classifies real PRs correctly.

### 2. Cross-platform core

Implement snapshot validation, local read/snooze state, attention transition
detection, and ranking. Keep this independent of Quickshell.

**Exit:** state survives restart; new activity reactivates read or snoozed PRs.

### 3. Native dashboard UI

Implement spacious parent cards, event timelines, filters, actions, and
loading/empty/stale/error states.

**Exit:** the default view identifies the next required action without expansion.

### 4. Platform integrations

Connect the existing Quickshell panel and Linux notifications to the new core,
then add macOS menu-bar and Windows tray integrations using the same core state.

**Exit:** each platform presents the same ranked PR state without reimplementing
GitHub logic.

### 5. Notification transition integration

Emit native notifications from core attention transitions and deep-link to the
relevant PR/dashboard state. Remove duplicate polling or notification logic.

**Exit:** one new attention event produces one notification and one dashboard item.

### 6. Validation

Add fixture-driven tests for ranking, filters, timelines, read/snooze behavior,
notification transitions, and stale/error handling. Validate all platform adapters
against the same core fixtures.

## Success criteria

Within seconds of opening the dashboard, I can identify every review I owe, every
PR of mine needing a response, every PR blocked by CI/conflicts/requested changes,
and the next browser destination for each item.
