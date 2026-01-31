#!/usr/bin/env bash
# Check if upstream xmannv/xkey has a newer version (same logic as in-app version check).
# LOCAL = commit that exists in upstream (merge-base of HEAD and upstream/main).
# Exit 0 = up to date, 1 = behind (new version available) or error.

set -e
UPSTREAM_REPO="https://github.com/xmannv/xkey"
REFS_URL="https://api.github.com/repos/xmannv/xkey/git/refs/heads/main"

git fetch "$UPSTREAM_REPO" main 2>/dev/null || true
REMOTE_SHA=$(git rev-parse FETCH_HEAD 2>/dev/null)
if [ -z "$REMOTE_SHA" ]; then
  REMOTE_SHA=$(curl -sS -H "Accept: application/vnd.github+json" "$REFS_URL" | jq -r '.object.sha')
fi
if [ -z "$REMOTE_SHA" ] || [ "$REMOTE_SHA" = "null" ]; then
  echo "Failed to get upstream main SHA"
  exit 1
fi

LOCAL=$(git merge-base HEAD "$REMOTE_SHA" 2>/dev/null) || LOCAL="$REMOTE_SHA"

COMPARE=$(curl -sS -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/xmannv/xkey/compare/${LOCAL}...${REMOTE_SHA}")
BEHIND=$(echo "$COMPARE" | jq -r '.behind_by // -1')

if [ "$BEHIND" = "null" ] || [ "$BEHIND" = "-1" ]; then
  echo "Version check failed or unable to compare"
  exit 1
fi

if [ "$BEHIND" -gt 0 ]; then
  echo "New version available (${BEHIND} commit(s) behind upstream). Remote: ${REMOTE_SHA:0:7}"
  exit 1
fi

echo "Up to date (${LOCAL:0:7})"
exit 0
