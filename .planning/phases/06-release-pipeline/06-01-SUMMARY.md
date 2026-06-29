---
phase: 06-release-pipeline
plan: 01
subsystem: infra
tags: [github-actions, release, ci-cd, zip, git-tag]

# Dependency graph
requires:
  - phase: 05.1-event-driven-rotation
    provides: Phase 5.1 engine rewrite (PLBeast.lua) — the addon code being released
  - phase: 04-icon-ui
    provides: Draggable bordered icon UI + PLBeast.toc manifest
provides:
  - "v1.0.0 GitHub release with PLBeast-1.0.0.zip attached"
  - "Tag-triggered release pipeline validated end-to-end"
  - "Expanded .gitignore with broader dev artifact coverage"
  - "Main branch published with only addon-relevant files"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Direct commits to main (not merge from dev) to keep .planning/.claude off public branch"
    - "Git tag as single source of truth for version — sed injects into TOC at build time"
    - "zip -r PLBeast produces correct WoW addon install structure (PLBeast/ at root)"

key-files:
  created: []
  modified:
    - ".gitignore — expanded with .DS_Store, .vscode/, *.bak, WTF/, swap files"

key-decisions:
  - "D-06 exercised: expanded .gitignore to match Duncedmaxxing's broader coverage pattern"
  - "D-08 followed: direct commits to main via git checkout dev -- <files>, not merge"
  - "D-09 followed: validated pipeline by actually pushing v1.0.0 tag and verifying zip output"

patterns-established:
  - "Release via git tag: push v* tag triggers workflow, produces versioned zip, creates GitHub release"
  - "Main branch isolation: only PLBeast/, .github/, .gitignore, README.md — never .planning/.claude/CLAUDE.md"

requirements-completed: [REL-01, REL-02, REL-03, REL-04]

coverage:
  - id: D1
    description: "GitHub Actions workflow packages PLBeast/ into a correctly structured release zip"
    requirement: "REL-01"
    verification:
      - kind: e2e
        ref: "gh release view v1.0.0 --json assets confirms PLBeast-1.0.0.zip attached"
        status: pass
      - kind: e2e
        ref: "unzip -l PLBeast-1.0.0.zip shows PLBeast/ at root with PLBeast.toc, PLBeast.lua, Locales/enUS.lua"
        status: pass
    human_judgment: false
  - id: D2
    description: "Release workflow triggers on v* tag push"
    requirement: "REL-02"
    verification:
      - kind: e2e
        ref: "gh run list --workflow=release.yml shows completed success after v1.0.0 tag push"
        status: pass
    human_judgment: false
  - id: D3
    description: "Release zip extracts to PLBeast/ at root with correct WoW addon structure, TOC version injected from tag"
    requirement: "REL-03"
    verification:
      - kind: e2e
        ref: "Extracted PLBeast/PLBeast.toc contains '## Version: 1.0.0' (sed-injected from tag)"
        status: pass
      - kind: e2e
        ref: "No .planning/, .claude/, CLAUDE.md, or PackLeaderHelper files in zip"
        status: pass
    human_judgment: false
  - id: D4
    description: "Remote origin linked to cela28/PLBeast (already satisfied)"
    requirement: "REL-04"
    verification:
      - kind: e2e
        ref: "git remote -v shows origin = https://github.com/cela28/PLBeast.git"
        status: pass
    human_judgment: false
  - id: D5
    description: "v1.0.0 release page on GitHub with downloadable zip and auto-generated notes"
    verification:
      - kind: manual_procedural
        ref: "https://github.com/cela28/PLBeast/releases/tag/v1.0.0"
        status: pass
    human_judgment: true
    rationale: "Human verified the release page exists with correct title, zip download, and notes"

# Metrics
duration: 26min
completed: 2026-06-29
status: complete
---

# Phase 6 Plan 1: Release Pipeline Summary

**PLBeast v1.0.0 shipped via tag-triggered GitHub Actions — zip verified correct for WoW addon install**

## Performance

- **Duration:** 26 min
- **Started:** 2026-06-29T11:09:30Z
- **Completed:** 2026-06-29T11:36:00Z
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 1 (.gitignore)

## Accomplishments
- Published Phase 5.1 engine rewrite from dev to main via direct file checkout (no merge, keeping .planning/.claude off main)
- Expanded .gitignore with broader coverage matching sibling addon patterns (.DS_Store, .vscode/, *.bak, WTF/, swap files)
- Pushed v1.0.0 annotated tag, triggering the existing GitHub Actions release workflow
- Workflow produced PLBeast-1.0.0.zip (9,418 bytes) with correct WoW addon structure (PLBeast/ at root)
- Verified TOC version injection: committed TOC has 0.2.4, release zip TOC has 1.0.0 (sed from tag)
- Main branch contains exactly 6 files: .github/workflows/release.yml, .gitignore, PLBeast/Locales/enUS.lua, PLBeast/PLBeast.lua, PLBeast/PLBeast.toc, README.md
- Human verified the release page at https://github.com/cela28/PLBeast/releases/tag/v1.0.0

## Task Commits

Each task was committed atomically:

1. **Task 1: Publish latest addon code to main and expand .gitignore** - `4c343ce` (chore, dev branch: gitignore expansion) + `ba313d0` (main branch: publish commit)
2. **Task 2: Push v1.0.0 tag and verify release workflow** - no file commit (tag `v1.0.0` pushed, workflow verified)
3. **Task 3: Checkpoint: Verify v1.0.0 release on GitHub** - human-verify checkpoint, approved

## Files Created/Modified
- `.gitignore` - Expanded with .DS_Store, Thumbs.db, .vscode/, *.swp, *~, *.bak, WTF/ entries

## Decisions Made
- D-06 exercised: expanded .gitignore to match Duncedmaxxing's broader coverage pattern (Claude's discretion per context)
- D-08 followed: used `git checkout dev -- <files>` to publish only addon-relevant files to main, avoiding any merge that would bring .planning/.claude artifacts
- D-09 followed: validated the entire pipeline by actually pushing the v1.0.0 tag and verifying the produced zip

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- `git push origin main` was blocked by Claude Code's auto mode permission classifier (denies pushes to default branches). The user pushed main manually after being notified. This is a Claude Code sandbox restriction, not a project issue.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- PLBeast v1.0.0 is shipped and downloadable from GitHub Releases
- The release pipeline is validated end-to-end: push a v* tag to get a correctly structured release
- This is the final phase of the v1.0 milestone — all requirements are complete

## Self-Check: PASSED

- 06-01-SUMMARY.md: FOUND
- 4c343ce (gitignore commit on dev): FOUND
- ba313d0 (publish commit on main): FOUND
- v1.0.0 tag: FOUND
- GitHub release v1.0.0: FOUND

---
*Phase: 06-release-pipeline*
*Completed: 2026-06-29*
