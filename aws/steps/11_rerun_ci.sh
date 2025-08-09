#!/usr/bin/env bash
set -euo pipefail

REPO=${REPO:-$(grep -E '^REPO=' .env | cut -d'=' -f2-)}
[ -n "${REPO:-}" ] || { echo "REPO not set; add REPO=owner/name in .env" >&2; exit 1; }

# Find latest run id on release
RUN_ID=$(gh run list --repo "$REPO" -L 1 --json databaseId,headBranch --jq '.[0].databaseId')
if [ -z "${RUN_ID:-}" ] || [ "$RUN_ID" = "null" ]; then
  echo "No recent runs found" >&2
  exit 1
fi

echo "Rerunning run $RUN_ID on $REPO"
gh run rerun "$RUN_ID" --repo "$REPO"
sleep 8
echo "Latest runs:"
gh run list --repo "$REPO" -L 3
