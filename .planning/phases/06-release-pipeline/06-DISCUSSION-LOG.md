# Phase 6: Release Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-22
**Phase:** 6-Release Pipeline
**Areas discussed:** Packaging, Version sync, Release notes, Distribution

---

## Packaging

| Option | Description | Selected |
|--------|-------------|----------|
| BigWigs packager | BigWigsMods/packager action — WoW-community standard; handles zip naming, GitHub release, TOC version substitution; needs .pkgmeta to isolate PLBeast/ | ✓ |
| Hand-rolled zip | Plain workflow: zip PLBeast/ then attach via gh release / softprops-action; no external action, no .pkgmeta | |

**User's choice:** BigWigs packager
**Notes:** The repo holds the addon in a `PLBeast/` subfolder alongside `PackLeaderHelper` and `.planning/`; isolating just `PLBeast/` into the zip was flagged as the main technical task for research/planning (CONTEXT D-02), validated against the existing manual zips.

---

## Version sync

| Option | Description | Selected |
|--------|-------------|----------|
| Inject from tag | Packager replaces `## Version: @project-version@` with the tag-derived version at build time; git tag = single source of truth | ✓ |
| Keep manual TOC bump | User hand-edits `## Version`, commits, tags to match; workflow ships TOC verbatim | |

**User's choice:** "Either works, not sure about the difference" → Claude recommended and selected **Inject from tag**
**Notes:** User was unsure of the distinction. Claude explained: manual bumps risk tag/TOC drift; tag-injection deletes a manual step and that class of bug, fitting the minimal-maintenance preference. Chosen on that basis; flagged as easily reversible to manual.

---

## Release notes

| Option | Description | Selected |
|--------|-------------|----------|
| Auto from commits | GitHub auto-generates notes from commits/PRs since last tag | |
| Minimal / empty | Bare title, zip attached, empty body; leanest, no upkeep | ✓ |
| CHANGELOG.md | Maintain CHANGELOG.md and feed matching section into release body | |

**User's choice:** Minimal / empty
**Notes:** No CHANGELOG exists today; user opted for zero maintenance. Planner to suppress any default packager-generated changelog if necessary.

---

## Distribution

| Option | Description | Selected |
|--------|-------------|----------|
| GitHub only | Publish to GitHub Releases only; no extra secrets/accounts | ✓ |
| Also CurseForge/Wago | Also upload to CurseForge / Wago / WoWInterface; needs project IDs + API token secrets | |

**User's choice:** GitHub only
**Notes:** Matches standalone/minimal ethos. CurseForge/Wago kept open as a future-milestone option since the BigWigs packager supports them natively.

---

## Claude's Discretion

- Workflow file name/path (e.g. `.github/workflows/release.yml`).
- Exact `.pkgmeta` contents and ignore rules (validated against the known-good manual zip layout).
- Release zip filename pattern (manual convention `PLBeast-vX.Y.Z.zip` is reasonable to keep).
- Whether to delete the loose manual zips or just gitignore them.
- Pinned action version/SHA for `BigWigsMods/packager`.

## Deferred Ideas

- Publish to CurseForge / Wago / WoWInterface (future milestone; packager supports natively).
- Rich release notes / CHANGELOG.md.
- Repo restructure (PLBeast as repo root, or splitting PackLeaderHelper into its own repo).
