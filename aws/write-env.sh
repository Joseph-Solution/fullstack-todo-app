#!/usr/bin/env bash

# Create or overwrite the project's .env with required variables for deployment.
# - Uses current AWS identity to fill AWS_ACCOUNT_ID
# - Leaves DATABASE_URL and REPO empty for you to fill or for later automation
#
# Usage:
#   REGION=ap-southeast-2 ./aws/write-env.sh

set -euo pipefail

REGION=${REGION:-${AWS_REGION:-ap-southeast-2}}
ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"

echo "Region: $REGION"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

cat > "$ENV_FILE" <<EOF
# Core AWS
AWS_REGION=$REGION
AWS_ACCOUNT_ID=$ACCOUNT_ID

# ECR
ECR_REPOSITORY=joseph-solution/fullstack-todo-app

# ECS
ECS_CLUSTER_NAME=todo-app-cluster
ECS_BACKEND_SERVICE_NAME=todo-backend-service
ECS_FRONTEND_SERVICE_NAME=todo-frontend-service

# ALB & Target Groups & Security Groups (names)
ALB_NAME=todo-app-alb
TG_FRONTEND_NAME=todo-frontend-tg
TG_BACKEND_NAME=todo-backend-tg
ALB_SG_NAME=todo-alb-sg
SVC_SG_NAME=todo-svc-sg

# App ports
FRONTEND_PORT=4567
BACKEND_PORT=5678

# App config (to be provided later)
DATABASE_URL=""
REPO=""
SECRET_DB_NAME=todo-database-url
EOF

echo ".env written to $ENV_FILE"
echo "Preview (DATABASE_URL redacted):"
sed -E 's#^(DATABASE_URL=).*#\1***redacted***#' "$ENV_FILE"


