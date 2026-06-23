---
created: 2026-06-23T20:59:07.378Z
title: Bump PLBeast.toc Version + add version-bump discipline
area: tooling
files:
  - PLBeast/PLBeast.toc (## Version: 0.2.4)
---

## Problem

`PLBeast.toc` is still `## Version: 0.2.4` — the version was never bumped when the
reset-on-relog/boss-pull feature landed (commit `5d59581`, quick task 260622-1or). That
shipped *after* the 0.2.4 Phase 5 builds, so two functionally different builds both report
`0.2.4`. This directly caused real confusion during Phase 2 verification: the installed
addon was a stale pre-reset 0.2.4 copy, indistinguishable by version from the current
0.2.4 code, so relog-reset appeared "broken" when it was just not installed.

## Solution

1. Bump `PLBeast.toc` `## Version` (e.g. → 0.2.5) to reflect the reset feature already
   present in the repo.
2. Establish the habit of bumping the version on every user-facing change so the in-game
   AddOn list reliably identifies the running build. This becomes largely moot once the
   Phase 6 release pipeline tags + packages builds — consider folding a version-stamp step
   into that workflow.
