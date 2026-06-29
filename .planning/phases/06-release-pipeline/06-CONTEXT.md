# Phase 6: Release Pipeline - Context

**Gathered:** 2026-06-29 (updated from 2026-06-22)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a GitHub Actions workflow on `cela28/PLBeast` that, when a `v*` tag is pushed, automatically packages the `PLBeast/` addon folder into a release zip (which unzips to `PLBeast/` at the WoW AddOns path — no nested subfolder) and publishes a GitHub release with that zip attached.

**In scope (REL-01..04):**
- GitHub Actions workflow that builds the release zip (REL-01)
- Triggered by pushing a git tag matching `v*` (REL-02)
- Zip structured for WoW install — extracts to `PLBeast/` at root, containing only the addon (REL-03)
- Remote origin linked to `cela28/PLBeast` (REL-04 — **already satisfied**)
- A GitHub release entry created automatically with the zip attached

**Out of scope:**
- Publishing to CurseForge / Wago / WoWInterface (deferred)
- Maintaining a CHANGELOG.md or rich hand-written release notes
- Restructuring the repo to make `PLBeast/` the repo root or splitting `PackLeaderHelper` into its own repo
- Any addon-code changes — this phase is CI/CD plumbing only

**Already true (do not re-do):**
- **REL-04 is complete** — `git remote -v` shows `origin = https://github.com/cela28/PLBeast.git`.
- **The release workflow already exists on `origin/main`** (commit `af2c235`) — tag-triggered, `zip` + `sed` + `gh release create`. It has never been triggered (no tags or releases exist yet).
- **The `.github/workflows/release.yml` follows the same pattern as Duncedmaxxing's workflow** — they are nearly identical (tag trigger, sed TOC version, zip, gh release create with --generate-notes).

</domain>

<decisions>
## Implementation Decisions

### Packaging Approach (REL-01, REL-03)
- **D-01:** Use simple `zip -r` + `gh release create` — NOT BigWigsMods/packager. This matches the proven pattern from Duncedmaxxing and SimpleCursorRing. The workflow already exists on main and is correct.
- **D-02 (DROPPED):** No `.pkgmeta` needed. The addon lives in a top-level `PLBeast/` folder, so `zip -r PLBeast` produces the correct structure directly. BigWigsMods/packager's subfolder isolation is unnecessary.

### TOC Version Source (REL-01)
- **D-03:** **Inject the version from the git tag via `sed`.** The workflow runs `sed -i "s/^## Version: .*/## Version: ${VERSION}/"` on the TOC before zipping, so the release zip always has the correct version matching the tag. The committed TOC stays at whatever was last manually bumped — only the zip artifact reflects the tag version. Same approach as Duncedmaxxing.

### Release Body / Notes
- **D-04:** **Auto-generated release notes via `--generate-notes`.** GitHub generates a changelog from commit messages between tags. Matches the pattern used by Duncedmaxxing (`Full Changelog` link) and HunterPetStatus. Low maintenance, gives users some context.

### Distribution Targets
- **D-05:** **GitHub Releases only.** No CurseForge / Wago / WoWInterface — matches the standalone/minimal ethos. Deferred to a future milestone.

### Repo Housekeeping
- **D-06:** `.gitignore` already exists (Zone.Identifier entries). The manual `PLBeast-v*.zip` files have been removed from the repo. Consider aligning `.gitignore` with Duncedmaxxing's broader coverage (`.DS_Store`, `.vscode/`, `*.bak`, etc.) — at Claude's discretion.

### Version & Release
- **D-07:** **First release is v1.0.0.** All 6 phases complete = first stable release. Clean milestone boundary.
- **D-08:** **Merge strategy: direct commits to main** (not merge dev→main). `.planning/`, `.claude/`, and `CLAUDE.md` must stay off main. Publish only addon-relevant files (`PLBeast/`, `.github/`, `.gitignore`, `README.md`) — same approach as Duncedmaxxing.

### Workflow Validation
- **D-09:** **Validate by actually pushing the v1.0.0 tag.** After publishing latest addon code to main, push `v1.0.0` tag, verify the workflow runs successfully and the produced zip has the correct internal layout (`PLBeast/PLBeast.toc`, `PLBeast/PLBeast.lua`, `PLBeast/Locales/enUS.lua`).

### Folded Todos
- **bump-plbeast-toc-version** — The "version-bump discipline" concern is addressed by D-03: the git tag is the single source of truth and sed injects it into the TOC at build time. No manual TOC bumps needed for releases.

### Claude's Discretion
- Whether to expand `.gitignore` to match Duncedmaxxing's broader pattern (D-06)
- Whether to remove the `PackLeaderHelper.lua` / `PackLeaderHelper.toc` from main (they exist on main from the original snapshot — only `PLBeast/` is the shipping addon)
- Release title format: current is `"PLBeast $GITHUB_REF_NAME"` vs Duncedmaxxing's `"$GITHUB_REF_NAME"` — either is fine
- Exact method for publishing dev changes to main (cherry-pick, checkout --path, fresh commits)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Definition
- `.planning/PROJECT.md` — Core value, constraints (minimal/standalone addon), and the "fully independent" key decision.
- `.planning/REQUIREMENTS.md` — Phase 6 maps to **REL-01, REL-02, REL-03, REL-04**.
- `.planning/ROADMAP.md` § "Phase 6: Release Pipeline" — Goal and the 4 success criteria.

### Addon Being Packaged (current state — the packaging target)
- `PLBeast/PLBeast.toc` — `## Interface: 120000, 120005, 120007`, `## Version: 0.2.4` (sed-injected at build time per D-03), `## SavedVariablesPerCharacter: PLBeastDB`, lists `Locales\enUS.lua` and `PLBeast.lua`.
- `PLBeast/PLBeast.lua` — main addon file (rewritten in Phase 5.1 with self-correcting CDM model).
- `PLBeast/Locales/enUS.lua` — locale table.
- These three files (under `PLBeast/`) are the **entire** contents that belong in the release zip.

### Existing Workflow (already on main — the starting point)
- `.github/workflows/release.yml` — Tag-triggered release workflow. Already functional, never triggered.

### Sibling Addon Patterns (reference for consistency)
- Duncedmaxxing `.github/workflows/release.yml` — Nearly identical workflow; proven working (produced `v1.0.0` release). **Copy this pattern.**
- Duncedmaxxing `.gitignore` — Broader coverage (Zone.Identifier, .DS_Store, .vscode/, *.bak, WTF/).
- SimpleCursorRing `.github/workflows/release.yml` — Alternative pattern (release-triggered, softprops action) — NOT used, but for reference.

### Must NOT be in the release zip (repo isolation)
- `PackLeaderHelper.lua`, `PackLeaderHelper.toc` (root — the original source addon, separate from PLBeast)
- `.planning/`, `CLAUDE.md`, `.claude/`, `Locales/` (root-level, belongs to PackLeaderHelper), `Media/`

### Must NOT be on main branch
- `.planning/` — GSD workflow artifacts, dev-only
- `.claude/` — Claude Code config, dev-only
- `CLAUDE.md` — project instructions, dev-only

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`.github/workflows/release.yml` already exists on main** — The workflow is written, functional, and follows the Duncedmaxxing pattern. Only needs validation via an actual tag push.
- **Duncedmaxxing's workflow** is the proven template — PLBeast's is already a copy of it.
- **Duncedmaxxing's `.gitignore`** can be copied for broader coverage.

### Established Patterns
- **Direct commits to main** — main is published independently from dev. `.planning/` artifacts never touch main. This is the pattern across all sibling addons (Duncedmaxxing, SimpleCursorRing, Hide-CD-Bling, HunterPetStatus).
- **Minimal-maintenance, decisive descoping** — consistent with Phases 4–5 where the user removed features they didn't want. Here: GitHub-only, auto-generated notes, no CHANGELOG.
- **Standalone / self-contained** — the addon ships independently of PackLeaderHelper; the zip isolation is the CI expression of that principle.

### Integration Points
- `.github/workflows/release.yml` on `origin/main` — exists, ready to trigger
- Git tag push (`v*`) on `cela28/PLBeast` — the trigger surface is live
- Dev branch has 18 commits ahead of main (Phase 5.1 engine rewrite + code review fixes) — these need to be published to main before tagging v1.0.0

</code_context>

<specifics>
## Specific Ideas

- Keep the release zip filename convention: `PLBeast-{VERSION}.zip` (matching Duncedmaxxing's `Duncedmaxxing-{VERSION}.zip`).
- The single source of truth for the version is the git tag (D-03) — push a tag, get a correctly-versioned zip and release with zero manual edits.
- Copy Duncedmaxxing's workflow and `.gitignore` patterns exactly where applicable — consistency across the addon portfolio.

</specifics>

<deferred>
## Deferred Ideas

- **Publish to CurseForge / Wago / WoWInterface** — GitHub-only for now. The simple zip approach doesn't preclude adding these later.
- **Rich release notes / CHANGELOG.md** — deferred; auto-generated notes are sufficient for now.
- **Repo restructure** (PLBeast as repo root, or splitting PackLeaderHelper into its own repo) — out of scope; the pipeline works within the current shared-repo layout.

### Reviewed Todos (not folded)
- **reconsider-login-boss-reset** — Rotation tracking concern, not release pipeline. Stays in pending todos for post-5.1 decision.
- **event-driven-rotation-tracking** — Completed by Phase 5.1. Todo should be closed separately.

</deferred>

---

*Phase: 6-Release Pipeline*
*Context gathered: 2026-06-29 (updated)*
