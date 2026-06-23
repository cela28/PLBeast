# Phase 6: Release Pipeline - Context

**Gathered:** 2026-06-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a GitHub Actions workflow on `cela28/PLBeast` that, when a `v*` tag is pushed, automatically packages the `PLBeast/` addon folder into a release zip (which unzips to `PLBeast/` at the WoW AddOns path — no nested subfolder) and publishes a GitHub release with that zip attached.

**In scope (REL-01..04):**
- GitHub Actions workflow that builds the release zip (REL-01)
- Triggered by pushing a git tag matching `v*` (REL-02)
- Zip structured for WoW install — extracts to `PLBeast/` at root, containing only the addon (REL-03)
- Remote origin linked to `cela28/PLBeast` (REL-04 — **already satisfied**, see below)
- A GitHub release entry created automatically with the zip attached

**Out of scope:**
- Publishing to CurseForge / Wago / WoWInterface (deferred — see Deferred Ideas)
- Maintaining a CHANGELOG.md or rich release notes (user chose minimal/empty body)
- Restructuring the repo to make `PLBeast/` the repo root or splitting `PackLeaderHelper` into its own repo
- Any addon-code changes — this phase is CI/CD plumbing only

**Already true (do not re-do):**
- **REL-04 is effectively complete** — `git remote -v` shows `origin = https://github.com/cela28/PLBeast.git`.
- **The target zip layout is already proven** — the five manual zips `PLBeast-v0.2.0..v0.2.4` all extract to `PLBeast/PLBeast.toc`, `PLBeast/PLBeast.lua`, `PLBeast/Locales/enUS.lua`. The workflow must reproduce exactly this structure.
- Tags `v0.1.0`, `v0.1.1`, `v0.1.2`, `v0.2.3`, `v0.2.4` already exist on the remote; current TOC `## Version` is `0.2.4`.

</domain>

<decisions>
## Implementation Decisions

### Packaging Approach (REL-01, REL-03)
- **D-01:** Use the **BigWigsMods/packager** GitHub Action (the WoW-community-standard packager) — not a hand-rolled `zip` step. It handles zip naming, GitHub release creation, and TOC version substitution natively.
- **D-02 (KEY RESEARCH ITEM — must be solved by planner):** The packager normally assumes the addon lives at the **repo root**, but in this repo the addon is in the `PLBeast/` subfolder, alongside `PackLeaderHelper.lua` / `PackLeaderHelper.toc` and `.planning/` at root. The zip must contain **only** `PLBeast/`. The researcher/planner must determine the exact, robust packager configuration that isolates `PLBeast/` and excludes everything else (the second addon, `.planning/`, the loose `PLBeast-v*.zip` artifacts, repo metadata). Likely involves a `.pkgmeta` (`package-as: PLBeast`, `ignore:` list, possibly `enable-toc-creation`) and/or staging only `PLBeast/` before the packager runs. **Validate against the known-good layout of the existing manual zips.**

### TOC Version Source (REL-01)
- **D-03:** **Inject the version from the git tag.** Put the packager's `@project-version@` keyword in `PLBeast.toc`'s `## Version` line so the packager substitutes the tag-derived version at build time. The git tag becomes the single source of truth; no more hand-editing `## Version`, and tag/TOC cannot drift. _(User was unsure between this and manual TOC bumps; chosen for minimal maintenance and to eliminate the drift bug. Easily reversible to manual if desired.)_

### Release Body / Notes
- **D-04:** **Minimal / empty release body.** No CHANGELOG.md, no auto-generated commit changelog to maintain. If the BigWigs packager generates a changelog by default, configure it to suppress / keep the body bare (research the relevant packager flag, e.g. changelog handling). Just the zip attached under a plain version title.

### Distribution Targets
- **D-05:** **GitHub Releases only.** No CurseForge / Wago / WoWInterface upload — matches the standalone/minimal ethos and avoids needing project IDs and API-token secrets. (Captured as a Deferred Idea for a future milestone.)

### Repo Housekeeping
- **D-06:** Add a `.gitignore` entry for the loose `PLBeast-v*.zip` build artifacts in the repo root (currently untracked). They are manual build leftovers and should not be committed; the pipeline produces release zips as workflow artifacts, not repo files.

### Claude's Discretion
- Workflow file name and path (e.g. `.github/workflows/release.yml`).
- Exact `.pkgmeta` contents and ignore rules (subject to D-02's validation against the known-good zip layout).
- The release zip's filename pattern (the manual convention was `PLBeast-vX.Y.Z.zip`; reasonable to keep).
- Whether to remove the existing committed/loose manual zips as part of housekeeping, or just gitignore them.
- Pinned action version / SHA for `BigWigsMods/packager`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Definition
- `.planning/PROJECT.md` — Core value, constraints (minimal/standalone addon, no dependency on PackLeaderHelper), and the "fully independent" key decision.
- `.planning/REQUIREMENTS.md` — Phase 6 maps to **REL-01, REL-02, REL-03, REL-04**.
- `.planning/ROADMAP.md` § "Phase 6: Release Pipeline" — Goal and the 4 success criteria (remote = cela28/PLBeast; `v*` tag triggers workflow; zip unzips to `PLBeast/`; GitHub release auto-created with zip).

### Addon Being Packaged (current state — the packaging target)
- `PLBeast/PLBeast.toc` — `## Interface: 120000, 120005, 120007`, `## Version: 0.2.4` (this is the line `@project-version@` replaces per D-03), `## SavedVariablesPerCharacter: PLBeastDB`, lists `Locales\enUS.lua` and `PLBeast.lua`.
- `PLBeast/PLBeast.lua` — main addon file.
- `PLBeast/Locales/enUS.lua` — locale table.
- These three files (under `PLBeast/`) are the **entire** contents that belong in the release zip.

### Known-Good Reference Artifacts (validate the workflow output against these)
- `PLBeast-v0.2.4.zip` (and `v0.2.0..v0.2.3`) in the repo root — manually built; demonstrate the exact correct internal layout: `PLBeast/PLBeast.toc`, `PLBeast/PLBeast.lua`, `PLBeast/Locales/enUS.lua`. The CI-produced zip must match this structure.

### Must NOT be in the release zip (repo isolation per D-02)
- `PackLeaderHelper.lua`, `PackLeaderHelper.toc` (root — the original source addon, separate from PLBeast)
- `.planning/`, `CLAUDE.md`, `Locales/` (root-level, belongs to PackLeaderHelper), `Media/`, the loose `PLBeast-v*.zip` files

### External Tooling Docs (researcher to consult)
- BigWigsMods/packager — GitHub Action repo & README (packaging flags, `.pkgmeta` schema: `package-as`, `ignore`, `enable-toc-creation`, `@project-version@` substitution, changelog/release-notes control, GitHub release creation via `GITHUB_TOKEN`). No in-repo precedent — net-new tooling for this project.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The five manual `PLBeast-v*.zip` files are a free correctness oracle — they encode the exact zip structure REL-03 requires. The planner should diff the CI zip against `PLBeast-v0.2.4.zip` to confirm parity.
- `PLBeast/PLBeast.toc` already carries multi-Interface support and a `## Version` line ready for `@project-version@` substitution.

### Established Patterns
- **Minimal-maintenance, decisive descoping** — consistent with Phases 4–5 where the user removed features they didn't want (sync toggle, color picker). Here: GitHub-only, empty release notes, no CHANGELOG.
- **Standalone / self-contained** — the addon must ship independently of PackLeaderHelper; the zip isolation (D-02) is the CI expression of that project principle.

### Integration Points
- New `.github/workflows/*.yml` — net-new; no existing workflows (`.github/workflows/` does not exist yet).
- New `.pkgmeta` at repo root (per the packager's expectations) — net-new.
- New/updated `.gitignore` — net-new (no `.gitignore` exists today).
- Git tag push (`v*`) on `cela28/PLBeast` is the trigger; tags are already being pushed to this remote, so the trigger surface is live.

</code_context>

<specifics>
## Specific Ideas

- Keep the release zip filename convention the user already established manually: `PLBeast-vX.Y.Z.zip`.
- The single source of truth for the version should be the git tag (D-03) — push a tag, get a correctly-versioned zip and release with zero manual edits.
- Treat `PLBeast-v0.2.4.zip` as the golden reference for "correct zip structure."

</specifics>

<deferred>
## Deferred Ideas

- **Publish to CurseForge / Wago / WoWInterface** — the BigWigs packager supports these natively, but they need project IDs and API-token secrets plus accounts on each site. Deferred to a future milestone; the packager choice (D-01) keeps the door open to add them later with minimal change.
- **Rich release notes / CHANGELOG.md** — deferred; user chose a minimal release body for now.
- **Repo restructure** (PLBeast as repo root, or splitting PackLeaderHelper into its own repo) — out of scope; the pipeline works within the current shared-repo layout via isolation (D-02).

</deferred>

---

*Phase: 6-Release Pipeline*
*Context gathered: 2026-06-22*
