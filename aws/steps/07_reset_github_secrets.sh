#!/usr/bin/env bash
set -euo pipefail
# Requires: gh CLI authenticated
# Usage: ./aws/steps/07_reset_github_secrets.sh

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) not found. Install from https://cli.github.com/" >&2
  exit 1
fi

# Helper: read key from .env and normalize (trim spaces/CR and surrounding quotes)
read_env() {
  local key="$1"
  local val=""
  if [ -f .env ]; then
    val=$(grep -E "^${key}=" .env | tail -n1 | cut -d= -f2- || true)
  fi
  if [ -z "${val}" ]; then
    val="${!key-}"
  fi
  printf "%s" "$val" | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//' | sed -e 's/^\"\(.*\)\"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

normalize() {
  printf "%s" "$1" | tr -d '\r' | sed 's/^[ \t]*//;s/[ \t]*$//' | tr -d '"' | tr -d "'"
}

REPO=$(read_env REPO)
if [ -z "${REPO}" ]; then
  echo "REPO (owner/name) is required. Set it in .env or export REPO first." >&2
  exit 1
fi

AWS_REGION=$(read_env AWS_REGION)
AWS_REGION=${AWS_REGION:-ap-southeast-2}
AWS_ACCOUNT_ID=$(read_env AWS_ACCOUNT_ID)
ECR_REPOSITORY=$(read_env ECR_REPOSITORY)
ECR_REPOSITORY=$(normalize "${ECR_REPOSITORY:-joseph-solution/fullstack-todo-app}")
ECS_CLUSTER_NAME=$(normalize "$(read_env ECS_CLUSTER_NAME || true)")
ECS_CLUSTER_NAME=${ECS_CLUSTER_NAME:-todo-app-cluster}
ECS_BACKEND_SERVICE_NAME=$(normalize "$(read_env ECS_BACKEND_SERVICE_NAME || true)")
ECS_BACKEND_SERVICE_NAME=${ECS_BACKEND_SERVICE_NAME:-todo-backend-service}
ECS_FRONTEND_SERVICE_NAME=$(normalize "$(read_env ECS_FRONTEND_SERVICE_NAME || true)")
ECS_FRONTEND_SERVICE_NAME=${ECS_FRONTEND_SERVICE_NAME:-todo-frontend-service}
ALB_DNS_NAME=$(read_env ALB_DNS_NAME)
GHA_OIDC_ROLE_ARN=$(read_env GHA_OIDC_ROLE_ARN)

# Optional (only set if provided in env; not read from .env for security)
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}

echo "Repo: $REPO"
echo "Preparing to set secrets (normalized):"
printf "  AWS_REGION=%s\n  AWS_ACCOUNT_ID=%s\n  ECR_REPOSITORY=%s\n  ECS_CLUSTER_NAME=%s\n  ECS_BACKEND_SERVICE_NAME=%s\n  ECS_FRONTEND_SERVICE_NAME=%s\n  ALB_DNS_NAME=%s\n" \
  "$AWS_REGION" "$AWS_ACCOUNT_ID" "$ECR_REPOSITORY" "$ECS_CLUSTER_NAME" "$ECS_BACKEND_SERVICE_NAME" "$ECS_FRONTEND_SERVICE_NAME" "${ALB_DNS_NAME:-}"

# Delete all existing secrets in the repo
EXISTING=$(gh secret list --repo "$REPO" --json name -q '.[].name' || true)
if [ -n "$EXISTING" ]; then
  echo "$EXISTING" | while read -r name; do
    [ -n "$name" ] && gh secret delete "$name" --repo "$REPO" -y || true
  done
  echo "Old secrets deleted."
else
  echo "No existing secrets to delete."
fi

set_secret() {
  local key="$1" val="$2"
  if [ -n "$val" ]; then
    echo "set $key"
    echo -n "$val" | gh secret set "$key" --repo "$REPO" --body - >/dev/null
  else
    echo "skip $key (empty)"
  fi
}

set_secret AWS_REGION "$AWS_REGION"
set_secret AWS_ACCOUNT_ID "$AWS_ACCOUNT_ID"
set_secret ECR_REPOSITORY "$ECR_REPOSITORY"
set_secret ECS_CLUSTER_NAME "$ECS_CLUSTER_NAME"
set_secret ECS_BACKEND_SERVICE_NAME "$ECS_BACKEND_SERVICE_NAME"
set_secret ECS_FRONTEND_SERVICE_NAME "$ECS_FRONTEND_SERVICE_NAME"
set_secret ALB_DNS_NAME "$ALB_DNS_NAME"
set_secret GHA_OIDC_ROLE_ARN "$GHA_OIDC_ROLE_ARN"
# Only set credentials if provided in env
set_secret AWS_ACCESS_KEY_ID "$AWS_ACCESS_KEY_ID"
set_secret AWS_SECRET_ACCESS_KEY "$AWS_SECRET_ACCESS_KEY"

echo "Secrets reset complete for $REPO"
