#!/usr/bin/env bash
#
# publish-to-main.sh — publish ONLY the installable addon + CI to the `main` branch.
#
# RULE: `main` contains exactly two paths, taken from the source branch (default: dev):
#   - PLBeast/    (the installable addon)
#   - .github/    (CI / release workflow)
# Working files (.planning/, scripts/, READMEs, etc.) are NEVER published to main.
#
# It builds main's tree with git plumbing in a temporary index, so it never
# touches your working tree or current branch. Run from the repo root.
#
# Usage:
#   scripts/publish-to-main.sh            # build from dev, commit to main, push
#   scripts/publish-to-main.sh dev        # explicit source branch
#   scripts/publish-to-main.sh dev --dry-run   # show what main's tree would be, no commit/push
#
set -euo pipefail

SOURCE_REF="dev"
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) SOURCE_REF="$arg" ;;
  esac
done

# Paths allowed on main. To change the rule, edit this list (must be tree paths in SOURCE_REF).
ALLOWED_PATHS=("PLBeast" ".github")

cd "$(git rev-parse --show-toplevel)"

# Resolve source tip (prefer local ref; fall back to remote-tracking).
if git rev-parse --verify --quiet "${SOURCE_REF}^{commit}" >/dev/null; then
  SRC="${SOURCE_REF}"
elif git rev-parse --verify --quiet "origin/${SOURCE_REF}^{commit}" >/dev/null; then
  SRC="origin/${SOURCE_REF}"
else
  echo "ERROR: source branch '${SOURCE_REF}' not found locally or on origin." >&2
  exit 1
fi

# Build main's tree in a throwaway index — working tree is untouched.
TMP_INDEX="$(mktemp -u "${TMPDIR:-/tmp}/plbeast-publish-index.XXXXXX")"
export GIT_INDEX_FILE="$TMP_INDEX"
trap 'rm -f "$TMP_INDEX"' EXIT
git read-tree --empty

for p in "${ALLOWED_PATHS[@]}"; do
  if git rev-parse --verify --quiet "${SRC}:${p}" >/dev/null; then
    git read-tree --prefix="${p}/" "${SRC}:${p}"
  else
    echo "WARNING: '${p}' not found in ${SRC} — skipping." >&2
  fi
done

TREE="$(git write-tree)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Source: ${SRC}"
  echo "main would contain exactly:"
  git ls-tree -r --name-only "$TREE" | sed 's/^/  /'
  exit 0
fi

PARENT="$(git rev-parse --verify --quiet refs/heads/main || true)"
MSG="release: publish .github/ + PLBeast/ from ${SRC}"
if [ -n "$PARENT" ]; then
  COMMIT="$(git commit-tree "$TREE" -p "$PARENT" -m "$MSG")"
else
  COMMIT="$(git commit-tree "$TREE" -m "$MSG")"
fi

git update-ref refs/heads/main "$COMMIT"
echo "Updated local main -> $(git rev-parse --short main)"
git push origin main
echo "Pushed main. Contents:"
git ls-tree -r --name-only main | sed 's/^/  /'
