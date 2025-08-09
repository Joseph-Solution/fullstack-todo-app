#!/usr/bin/env bash

# Phase A: Bootstrap base resources
# - Create ECR repository
# - Create CloudWatch log groups
# - Recreate IAM roles: ecsTaskExecutionRole (attach AmazonECSTaskExecutionRolePolicy), ecsTaskRole
# - Create ECS cluster
#
# Usage:
#   ./aws/phase-a-bootstrap.sh

set -euo pipefail

ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }

get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//'; }

REGION=$(get_env AWS_REGION)
ACCOUNT_ID=$(get_env AWS_ACCOUNT_ID)
ECR_REPO=$(get_env ECR_REPOSITORY)
CLUSTER=$(get_env ECS_CLUSTER_NAME)

echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"
echo "ECR: $ECR_REPO"
echo "Cluster: $CLUSTER"

echo "[ECR] Ensuring repository..."
aws ecr create-repository --region "$REGION" --repository-name "$ECR_REPO" >/dev/null 2>&1 || echo "  Exists: $ECR_REPO"

echo "[Logs] Ensuring log groups..."
aws logs create-log-group --region "$REGION" --log-group-name /ecs/todo-backend >/dev/null 2>&1 || echo "  Exists: /ecs/todo-backend"
aws logs create-log-group --region "$REGION" --log-group-name /ecs/todo-frontend >/dev/null 2>&1 || echo "  Exists: /ecs/todo-frontend"

# Prepare assume role policy document in a temp file to avoid JSON escaping issues
ASSUME_DOC_FILE=$(mktemp)
cat > "$ASSUME_DOC_FILE" <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ecs-tasks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
JSON

echo "[IAM] Ensuring ecsTaskExecutionRole..."
if ! aws iam get-role --role-name ecsTaskExecutionRole >/dev/null 2>&1; then
  aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://"$ASSUME_DOC_FILE" >/dev/null
  aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy >/dev/null
else
  echo "  Exists: ecsTaskExecutionRole"
fi

echo "[IAM] Ensuring ecsTaskRole..."
if ! aws iam get-role --role-name ecsTaskRole >/dev/null 2>&1; then
  aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file://"$ASSUME_DOC_FILE" >/dev/null
else
  echo "  Exists: ecsTaskRole"
fi

echo "[ECS] Ensuring cluster..."
aws ecs create-cluster \
  --region "$REGION" \
  --cluster-name "$CLUSTER" \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 >/dev/null 2>&1 || echo "  Exists: $CLUSTER"

echo "Phase A completed."

# Cleanup temp file
rm -f "$ASSUME_DOC_FILE" || true


