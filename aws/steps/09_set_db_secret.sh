#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }

# Load env
get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2-; }
AWS_REGION=${AWS_REGION:-$(get_env AWS_REGION)}
DATABASE_URL=${DATABASE_URL:-$(get_env DATABASE_URL)}
SECRET_NAME=${SECRET_NAME:-todo-database-url}

[ -n "${AWS_REGION:-}" ] || { echo "AWS_REGION is empty" >&2; exit 1; }
[ -n "${DATABASE_URL:-}" ] || { echo "DATABASE_URL is empty in .env" >&2; exit 1; }

# Create or update secret
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$DATABASE_URL" \
    --region "$AWS_REGION" >/dev/null
  echo "Updated secret: $SECRET_NAME"
else
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --secret-string "$DATABASE_URL" \
    --region "$AWS_REGION" >/dev/null
  echo "Created secret: $SECRET_NAME"
fi
