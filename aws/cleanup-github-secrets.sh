#!/usr/bin/env bash

# Delete all repository GitHub Secrets except a whitelist.
# Whitelist: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
#
# Usage:
#   ./aws/cleanup-github-secrets.sh
# Requirements:
#   - GitHub CLI (gh) authenticated with access to the repo
#   - .env contains REPO="owner/name"

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) not found. Install from https://cli.github.com/" >&2
  exit 1
fi

ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }

get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//'; }
REPO=$(get_env REPO)

if [[ -z "$REPO" ]]; then
  echo "REPO is empty in .env. Set REPO=owner/name" >&2
  exit 1
fi

echo "Repo: $REPO"
OWNER=${REPO%%/*}
REPO_NAME=${REPO#*/}

# Whitelist set
declare -A KEEP
KEEP["AWS_ACCESS_KEY_ID"]=1
KEEP["AWS_SECRET_ACCESS_KEY"]=1

echo "Listing secrets..."
mapfile -t NAMES < <(gh secret list --repo "$REPO" --json name --jq '.[].name')

if [[ ${#NAMES[@]} -eq 0 ]]; then
  echo "No secrets found."
  exit 0
fi

TO_DELETE=()
for n in "${NAMES[@]}"; do
  if [[ -z "${KEEP[$n]:-}" ]]; then
    TO_DELETE+=("$n")
  fi
done

if [[ ${#TO_DELETE[@]} -eq 0 ]]; then
  echo "Nothing to delete (only whitelist present)."
  exit 0
fi

echo "Will delete these secrets:"; printf '  - %s\n' "${TO_DELETE[@]}"

for n in "${TO_DELETE[@]}"; do
  echo "Deleting: $n"
  # Use GitHub REST API to avoid interactive confirmation
  gh api -X DELETE \
    repos/"$OWNER"/"$REPO_NAME"/actions/secrets/"$n" \
    >/dev/null 2>&1 || echo "  Skipped or already removed: $n"
done

echo "Cleanup completed."


