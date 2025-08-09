#!/usr/bin/env bash

# Set required GitHub Secrets for deployment (AK/SK mode).
# Keys set:
# - AWS_REGION, AWS_ACCOUNT_ID, ECR_REPOSITORY, ECS_CLUSTER_NAME,
#   ECS_BACKEND_SERVICE_NAME, ECS_FRONTEND_SERVICE_NAME, SECRET_DB_NAME
#
# Usage:
#   ./aws/set-github-secrets.sh

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
AWS_REGION=$(get_env AWS_REGION)
AWS_ACCOUNT_ID=$(get_env AWS_ACCOUNT_ID)
ECR_REPOSITORY=$(get_env ECR_REPOSITORY)
ECS_CLUSTER_NAME=$(get_env ECS_CLUSTER_NAME)
ECS_BACKEND_SERVICE_NAME=$(get_env ECS_BACKEND_SERVICE_NAME)
ECS_FRONTEND_SERVICE_NAME=$(get_env ECS_FRONTEND_SERVICE_NAME)
SECRET_DB_NAME=$(get_env SECRET_DB_NAME)

echo "Repo: $REPO"

set_secret() {
  local key="$1" val="$2"
  echo "Setting $key"
  gh secret set "$key" --repo "$REPO" --body "$val" >/dev/null
}

set_secret AWS_REGION "$AWS_REGION"
set_secret AWS_ACCOUNT_ID "$AWS_ACCOUNT_ID"
set_secret ECR_REPOSITORY "$ECR_REPOSITORY"
set_secret ECS_CLUSTER_NAME "$ECS_CLUSTER_NAME"
set_secret ECS_BACKEND_SERVICE_NAME "$ECS_BACKEND_SERVICE_NAME"
set_secret ECS_FRONTEND_SERVICE_NAME "$ECS_FRONTEND_SERVICE_NAME"
set_secret SECRET_DB_NAME "${SECRET_DB_NAME:-todo-database-url}"

echo "GitHub Secrets set (excluding AK/SK which you already provided)."


