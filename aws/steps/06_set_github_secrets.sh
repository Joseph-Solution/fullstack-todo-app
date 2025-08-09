#!/usr/bin/env bash
set -euo pipefail
# Optional: requires GitHub CLI (gh) and repo write access
# Usage: export REPO=owner/name; ./06_set_github_secrets.sh

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) not found. Install from https://cli.github.com/" >&2
  exit 1
fi

: "${REPO:?Set REPO=owner/name first}"

# Required values: export them before running, or edit defaults here
AWS_REGION=${AWS_REGION:-ap-southeast-2}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-}
ECR_REPOSITORY=${ECR_REPOSITORY:-joseph-solution/fullstack-todo-app}
ECS_CLUSTER_NAME=${ECS_CLUSTER_NAME:-todo-app-cluster}
ECS_BACKEND_SERVICE_NAME=${ECS_BACKEND_SERVICE_NAME:-todo-backend-service}
ECS_FRONTEND_SERVICE_NAME=${ECS_FRONTEND_SERVICE_NAME:-todo-frontend-service}
ALB_DNS_NAME=${ALB_DNS_NAME:-}

set_secret() {
  local key="$1" val="$2"
  echo "$key=$val"
  echo -n "$val" | gh secret set "$key" --repo "$REPO" --body - >/dev/null
}

set_secret AWS_REGION "$AWS_REGION"
[ -n "$AWS_ACCOUNT_ID" ] && set_secret AWS_ACCOUNT_ID "$AWS_ACCOUNT_ID" || true
set_secret ECR_REPOSITORY "$ECR_REPOSITORY"
set_secret ECS_CLUSTER_NAME "$ECS_CLUSTER_NAME"
set_secret ECS_BACKEND_SERVICE_NAME "$ECS_BACKEND_SERVICE_NAME"
set_secret ECS_FRONTEND_SERVICE_NAME "$ECS_FRONTEND_SERVICE_NAME"
[ -n "$ALB_DNS_NAME" ] && set_secret ALB_DNS_NAME "$ALB_DNS_NAME" || true

echo "GitHub secrets set for $REPO"
