#!/usr/bin/env bash
set -euo pipefail

# Resolve project root and .env path
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

# Defaults (can be overridden via exported env before running)
REGION=${REGION:-ap-southeast-2}
ACCOUNT_ID=${ACCOUNT_ID:-248729599833}
ECR_REPO=${ECR_REPO:-joseph-solution/fullstack-todo-app}
CLUSTER_NAME=${CLUSTER_NAME:-todo-app-cluster}
BACKEND_SERVICE=${BACKEND_SERVICE:-todo-backend-service}
FRONTEND_SERVICE=${FRONTEND_SERVICE:-todo-frontend-service}
FRONTEND_PORT=${FRONTEND_PORT:-4567}
BACKEND_PORT=${BACKEND_PORT:-5678}

# Discover ALB DNS if possible
ALB_DNS=$(aws elbv2 describe-load-balancers --region "$REGION" --names todo-app-alb --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "")

upsert() {
  local key="$1" val="$2" file="$3"
  if [ -f "$file" ] && grep -q "^${key}=" "$file"; then
    sed -i "s#^${key}=.*#${key}=${val}#" "$file"
  else
    echo "${key}=${val}" >> "$file"
  fi
}

# Ensure file exists
[ -f "$ENV_FILE" ] || touch "$ENV_FILE"

upsert AWS_REGION "$REGION" "$ENV_FILE"
upsert AWS_ACCOUNT_ID "$ACCOUNT_ID" "$ENV_FILE"
upsert ECR_REPOSITORY "$ECR_REPO" "$ENV_FILE"
upsert ECS_CLUSTER_NAME "$CLUSTER_NAME" "$ENV_FILE"
upsert ECS_BACKEND_SERVICE_NAME "$BACKEND_SERVICE" "$ENV_FILE"
upsert ECS_FRONTEND_SERVICE_NAME "$FRONTEND_SERVICE" "$ENV_FILE"
[ -n "$ALB_DNS" ] && upsert ALB_DNS_NAME "$ALB_DNS" "$ENV_FILE" || true
upsert FRONTEND_PORT "$FRONTEND_PORT" "$ENV_FILE"
upsert BACKEND_PORT "$BACKEND_PORT" "$ENV_FILE"

# Show result (redact potential sensitive keys if present)
sed -E 's#^(AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID)=.*#\1=****#' "$ENV_FILE"
