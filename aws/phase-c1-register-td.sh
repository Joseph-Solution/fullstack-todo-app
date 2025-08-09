#!/usr/bin/env bash

# Phase C1: Register ECS task definitions (backend and frontend)

set -euo pipefail

ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }
get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//'; }

REGION=$(get_env AWS_REGION)

echo "Region: $REGION"

aws ecs register-task-definition --region "$REGION" --cli-input-json file://"$ROOT_DIR/aws/task-definition-backend.json"
aws ecs register-task-definition --region "$REGION" --cli-input-json file://"$ROOT_DIR/aws/task-definition-frontend.json"

echo "Phase C1 completed: Registered task definitions todo-backend and todo-frontend."


