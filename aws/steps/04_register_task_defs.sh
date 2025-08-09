#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

aws ecs register-task-definition --region "$REGION" --cli-input-json file://$(dirname "$SCRIPT_DIR")/task-definition-backend.json
aws ecs register-task-definition --region "$REGION" --cli-input-json file://$(dirname "$SCRIPT_DIR")/task-definition-frontend.json

echo "Task definitions registered: todo-backend, todo-frontend"
