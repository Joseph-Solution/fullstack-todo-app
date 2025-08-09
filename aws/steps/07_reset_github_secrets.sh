#!/usr/bin/env bash
set -euo pipefail
# Requires: gh CLI authenticated, AWS CLI for ALB DNS lookup
# Usage: export REPO=owner/name; export needed envs; ./07_reset_github_secrets.sh

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) not found. Install from https://cli.github.com/" >&2
  exit 1
fi

: "${REPO:?Set REPO=owner/name first}"

AWS_REGION=${AWS_REGION:-ap-southeast-2}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-}
ECR_REPOSITORY=${ECR_REPOSITORY:-joseph-solution/fullstack-todo-app}
ECS_CLUSTER_NAME=${ECS_CLUSTER_NAME:-todo-app-cluster}
ECS_BACKEND_SERVICE_NAME=${ECS_BACKEND_SERVICE_NAME:-todo-backend-service}
ECS_FRONTEND_SERVICE_NAME=${ECS_FRONTEND_SERVICE_NAME:-todo-frontend-service}
ALB_DNS_NAME=${ALB_DNS_NAME:-$(aws elbv2 describe-load-balancers --region ${AWS_REGION} --names todo-app-alb --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "")}

# Optional (only set if provided)
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}

echo "Repo: $REPO"

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
# Only set credentials if provided in env
set_secret AWS_ACCESS_KEY_ID "$AWS_ACCESS_KEY_ID"
set_secret AWS_SECRET_ACCESS_KEY "$AWS_SECRET_ACCESS_KEY"

echo "Secrets reset complete for $REPO"
