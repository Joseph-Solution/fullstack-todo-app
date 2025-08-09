#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT_DIR"

ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found: $ENV_FILE" >&2; exit 1; }

get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2-; }

AWS_REGION=${AWS_REGION:-$(get_env AWS_REGION)}
REPO=${REPO:-$(get_env REPO)}
[ -n "${AWS_REGION:-}" ] || { echo "AWS_REGION missing in .env" >&2; exit 1; }
[ -n "${REPO:-}" ] || { echo "REPO (owner/name) missing in .env" >&2; exit 1; }

printf '== .env DATABASE_URL ==\n'
if grep -n '^DATABASE_URL=' "$ENV_FILE" >/dev/null 2>&1; then
  grep -n '^DATABASE_URL=' "$ENV_FILE" | sed -E 's#(DATABASE_URL=).*#\1***redacted***#'
else
  echo "DATABASE_URL not set"
fi

printf '\n== Secret todo-database-url ==\n'
if aws secretsmanager describe-secret --secret-id todo-database-url --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "Secret exists: todo-database-url"
else
  echo "Secret MISSING: todo-database-url"
fi

printf '\n== RDS status ==\n'
DB_ID=${DB_ID:-todo-db-instance}
read EP PORT USER DBNAME < <(aws rds describe-db-instances \
  --db-instance-identifier "$DB_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].[Endpoint.Address,Endpoint.Port,MasterUsername,DBName]' \
  --output text)
if [ -z "${EP:-}" ] || [ "$EP" = "None" ]; then
  echo "RDS instance not found: $DB_ID"
else
  STATUS=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$AWS_REGION" --query 'DBInstances[0].DBInstanceStatus' --output text)
  echo "Status=$STATUS Endpoint=$EP Port=$PORT DB=$DBNAME"
fi

printf '\n== ECS services ==\n'
aws ecs describe-services \
  --cluster $(get_env ECS_CLUSTER_NAME) \
  --services $(get_env ECS_BACKEND_SERVICE_NAME) $(get_env ECS_FRONTEND_SERVICE_NAME) \
  --region "$AWS_REGION" \
  --query 'services[].{name:serviceName,status:status,desired:desiredCount,running:runningCount}' \
  --output table || true

printf '\n== Re-run latest CI ==\n'
# Get latest run id on the repo
RUN_ID=$(gh run list --repo "$REPO" -L 1 --json databaseId --jq '.[0].databaseId')
if [ -z "${RUN_ID:-}" ] || [ "$RUN_ID" = "null" ]; then
  echo "No recent runs found for $REPO" >&2; exit 1;
fi

echo "Rerunning run $RUN_ID on $REPO"
gh run rerun "$RUN_ID" --repo "$REPO"

sleep 8

echo "\nLatest run summary:"
gh run list --repo "$REPO" -L 1
