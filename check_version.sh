#!/usr/bin/env bash
# Check if upstream xmannv/xkey or origin sonthepham-dev/xkey has a newer version (same logic as in-app version check).
# Exit 0 = up to date with both, 1 = behind either repo (new version available) or error.

set -e
UPSTREAM_REPO="https://github.com/xmannv/xkey"
ORIGIN_REPO="https://github.com/sonthepham-dev/xkey"
UPSTREAM_REFS="https://api.github.com/repos/xmannv/xkey/git/refs/heads/main"
ORIGIN_REFS="https://api.github.com/repos/sonthepham-dev/xkey/git/refs/heads/main"

git fetch "$UPSTREAM_REPO" main 2>/dev/null || true
REMOTE_UP=$(git rev-parse FETCH_HEAD 2>/dev/null) || true
if [ -z "$REMOTE_UP" ]; then
  REMOTE_UP=$(curl -sS -H "Accept: application/vnd.github+json" "$UPSTREAM_REFS" | jq -r '.object.sha')
fi
if [ -z "$REMOTE_UP" ] || [ "$REMOTE_UP" = "null" ]; then
  echo "Failed to get upstream main SHA"
  exit 1
fi
LOCAL_UP=$(git merge-base HEAD "$REMOTE_UP" 2>/dev/null) || LOCAL_UP="$REMOTE_UP"
COMPARE_UP=$(curl -sS -H "Accept: application/vnd.github+json" "https://api.github.com/repos/xmannv/xkey/compare/${LOCAL_UP}...${REMOTE_UP}")
BEHIND_UP=$(echo "$COMPARE_UP" | jq -r '.behind_by // -1')
if [ "$BEHIND_UP" = "null" ] || [ "$BEHIND_UP" = "-1" ]; then
  echo "Version check failed or unable to compare (upstream)"
  exit 1
fi
BEHIND_UPSTREAM=""
if [ "$BEHIND_UP" -gt 0 ]; then
  BEHIND_UPSTREAM="${BEHIND_UP}"
fi

REMOTE_OR=$(curl -sS -H "Accept: application/vnd.github+json" "$ORIGIN_REFS" | jq -r '.object.sha')
if [ -z "$REMOTE_OR" ] || [ "$REMOTE_OR" = "null" ]; then
  if [ -n "$BEHIND_UPSTREAM" ]; then
    echo "New version available (${BEHIND_UPSTREAM} commit(s) behind upstream). Remote: ${REMOTE_UP:0:7}"
    exit 1
  fi
  echo "Up to date (${LOCAL_UP:0:7}); could not check origin"
  exit 0
fi
git fetch "$ORIGIN_REPO" main 2>/dev/null || true
REMOTE_OR_FETCH=$(git rev-parse FETCH_HEAD 2>/dev/null) || true
if [ -n "$REMOTE_OR_FETCH" ]; then
  REMOTE_OR="$REMOTE_OR_FETCH"
fi
LOCAL_OR=$(git merge-base HEAD "$REMOTE_OR" 2>/dev/null) || LOCAL_OR="$REMOTE_OR"
COMPARE_OR=$(curl -sS -H "Accept: application/vnd.github+json" "https://api.github.com/repos/sonthepham-dev/xkey/compare/${LOCAL_OR}...${REMOTE_OR}")
BEHIND_OR=$(echo "$COMPARE_OR" | jq -r '.behind_by // -1')
if [ "$BEHIND_OR" = "null" ] || [ "$BEHIND_OR" = "-1" ]; then
  if [ -n "$BEHIND_UPSTREAM" ]; then
    echo "New version available (${BEHIND_UPSTREAM} commit(s) behind upstream). Remote: ${REMOTE_UP:0:7}"
    exit 1
  fi
  echo "Up to date (${LOCAL_UP:0:7}); could not compare origin"
  exit 0
fi
BEHIND_ORIGIN=""
if [ "$BEHIND_OR" -gt 0 ]; then
  BEHIND_ORIGIN="${BEHIND_OR}"
fi

if [ -n "$BEHIND_UPSTREAM" ] && [ -n "$BEHIND_ORIGIN" ]; then
  echo "New version available (${BEHIND_UPSTREAM} commit(s) behind upstream, ${BEHIND_ORIGIN} behind origin). Upstream: ${REMOTE_UP:0:7}, Origin: ${REMOTE_OR:0:7}"
  exit 1
fi
if [ -n "$BEHIND_UPSTREAM" ]; then
  echo "New version available (${BEHIND_UPSTREAM} commit(s) behind upstream). Remote: ${REMOTE_UP:0:7}"
  exit 1
fi
if [ -n "$BEHIND_ORIGIN" ]; then
  echo "New version available (${BEHIND_ORIGIN} commit(s) behind origin). Remote: ${REMOTE_OR:0:7}"
  exit 1
fi

echo "Up to date with both repos (${LOCAL_UP:0:7})"
exit 0
