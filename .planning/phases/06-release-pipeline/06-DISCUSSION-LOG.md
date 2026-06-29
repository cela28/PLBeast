# Phase 6: Release Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-29 (updated from 2026-06-22)
**Phase:** 06-release-pipeline
**Areas discussed:** Packaging approach, Trigger style, TOC version injection, Release notes style, Version & merge strategy, Workflow validation

**Update context:** Original discussion on 2026-06-22 chose BigWigsMods/packager. Since then, a simple zip workflow was created on `origin/main` (matching Duncedmaxxing's pattern), Phase 5.1 completed, and manual zips were removed. This update revises decisions to match the actual implementation and sibling addon patterns.

---

## Packaging Approach (revised from 2026-06-22)

**Original (2026-06-22):**

| Option | Description | Selected |
|--------|-------------|----------|
| BigWigs packager | BigWigsMods/packager action with .pkgmeta | ✓ (original) |
| Hand-rolled zip | Plain zip + gh release | |

**Update (2026-06-29):**

| Option | Description | Selected |
|--------|-------------|----------|
| Simple zip (current) | `zip -r` + `gh release create` — already on main, matches Duncedmaxxing | ✓ |
| BigWigs packager | Overengineered for a single-subfolder addon | |

**User's directive:** "Check your parent directory to see what Duncedmaxxing is doing and the other addons and copy them."
**Notes:** Validated all sibling addons — Duncedmaxxing's workflow is nearly identical to PLBeast's current one. D-01 revised, D-02 dropped.

---

## Trigger Style (new area)

| Option | Description | Selected |
|--------|-------------|----------|
| Tag push (current) | Push a `v*` tag → workflow creates release + zip | ✓ |
| Release created (SCR pattern) | Create release manually → workflow attaches zip | |

**User's choice:** Tag push
**Notes:** Matches current workflow and Duncedmaxxing. One-step process.

---

## TOC Version Injection (revised)

**Original:** `@project-version@` substitution via BigWigs packager

| Option | Description | Selected |
|--------|-------------|----------|
| Keep sed (current) | Workflow seds tag version into TOC before zipping | ✓ |
| Drop sed (SCR pattern) | Manually bump TOC before tagging | |
| Use @project-version@ | Placeholder in TOC, packager substitutes | |

**User's choice:** Keep sed — same as Duncedmaxxing.

---

## Release Notes Style (revised)

**Original:** Minimal / empty body

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-generated (current) | `--generate-notes` from commits | ✓ |
| Empty body | Just the zip, no notes | |

**User's choice:** Auto-generated
**Notes:** User asked to verify sibling addon patterns first. Duncedmaxxing v1.0.0 and HunterPetStatus v1.4.3 both show auto-generated "Full Changelog" links. Changed from original D-04 (empty) to match the portfolio pattern.

---

## Version & Merge Strategy (new area)

| Option | Description | Selected |
|--------|-------------|----------|
| v1.0.0 | All phases complete = first stable release | ✓ |
| v0.3.0 | Continue 0.x series | |
| Claude decides | Pick based on patterns | |

**User's choice:** v1.0.0
**Notes:** User reminded about file location rules: `.planning/`, `.claude/`, `CLAUDE.md` must not be on main. Confirmed "direct commits to main" (not merge dev→main) is the pattern — same as Duncedmaxxing.

---

## Claude's Discretion

- `.gitignore` expansion (align with Duncedmaxxing or leave minimal)
- Cleanup of PackLeaderHelper files from main (they exist from the original snapshot)
- Release title format (`PLBeast vX.Y.Z` vs `vX.Y.Z`)
- Exact method for publishing dev addon code to main (cherry-pick, checkout --path, fresh commits)

## Deferred Ideas

- CurseForge / Wago / WoWInterface publishing (future milestone)
- Rich release notes / CHANGELOG.md
- Repo restructure (PLBeast as repo root, or split PackLeaderHelper)
