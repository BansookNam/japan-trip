#!/usr/bin/env bash
# Deploy to GitHub Pages (source: main branch, / root).
# Usage: ./deploy.sh ["commit message"]
set -euo pipefail

cd "$(dirname "$0")"

BRANCH="main"
REPO="BansookNam/japan-trip"
SITE_URL="http://bansook.xyz/japan-trip/"
MSG="${1:-Update site $(date '+%Y-%m-%d %H:%M')}"

current=$(git rev-parse --abbrev-ref HEAD)
if [[ "$current" != "$BRANCH" ]]; then
  echo "✗ On branch '$current'. Switch to '$BRANCH' first." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "→ Committing changes:"
  git status --short
  git add -A
  git commit -m "$MSG"
else
  echo "→ No local changes to commit."
fi

echo "→ Pulling latest from origin/$BRANCH"
git pull --rebase origin "$BRANCH"

echo "→ Pushing to origin/$BRANCH"
git push origin "$BRANCH"

# Wait for the Pages build to finish (requires gh CLI; skipped if unavailable).
if command -v gh >/dev/null 2>&1; then
  sha=$(git rev-parse HEAD)
  echo "→ Waiting for GitHub Pages build of ${sha:0:7}..."
  for _ in $(seq 1 60); do
    read -r status commit < <(gh api "repos/$REPO/pages/builds/latest" \
      --jq '"\(.status) \(.commit)"' 2>/dev/null || echo "unknown none")
    if [[ "$commit" == "$sha" && "$status" == "built" ]]; then
      echo "✓ Deployed: $SITE_URL"
      exit 0
    elif [[ "$commit" == "$sha" && "$status" == "errored" ]]; then
      echo "✗ Pages build errored. Check https://github.com/$REPO/actions" >&2
      exit 1
    fi
    sleep 5
  done
  echo "… Build still running after 5 min. Check https://github.com/$REPO/actions"
else
  echo "✓ Pushed. Site will update shortly: $SITE_URL"
fi
