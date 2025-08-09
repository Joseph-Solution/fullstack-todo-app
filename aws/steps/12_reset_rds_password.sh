#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
REGION=${REGION:-$(grep -E '^AWS_REGION=' "$ENV_FILE" | cut -d'=' -f2- || echo ap-southeast-2)}
DB_ID=${DB_ID:-todo-db-instance}
SECRET_NAME=${SECRET_NAME:-todo-database-url}

# 1) Fetch RDS details
read EP PORT USER DBNAME < <(aws rds describe-db-instances \
  --db-instance-identifier "$DB_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].[Endpoint.Address,Endpoint.Port,MasterUsername,DBName]' \
  --output text)

if [ -z "${EP:-}" ] || [ "$EP" = "None" ]; then
  echo "RDS instance not found: $DB_ID (region: $REGION)" >&2
  exit 1
fi

# 2) Generate a strong alphanumeric password (URL-safe)
NEW_PW=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)

# 3) Reset master password and wait until available
aws rds modify-db-instance \
  --db-instance-identifier "$DB_ID" \
  --master-user-password "$NEW_PW" \
  --apply-immediately \
  --region "$REGION" >/dev/null

echo "Waiting for RDS to become available..."
aws rds wait db-instance-available \
  --db-instance-identifier "$DB_ID" \
  --region "$REGION"

echo "RDS is available."

# 4) Build DATABASE_URL and update .env
DB_URL="postgresql://${USER}:${NEW_PW}@${EP}:${PORT}/${DBNAME}"
# remove existing line
sed -i '/^DATABASE_URL=/d' "$ENV_FILE" || true
# append new (quoted)
echo "DATABASE_URL='${DB_URL}'" >> "$ENV_FILE"

echo "Updated .env (DATABASE_URL redacted):"
grep -n '^DATABASE_URL=' "$ENV_FILE" | sed -E 's#(DATABASE_URL=).*#\1***redacted***#'

# 5) Upsert Secrets Manager secret for the app to consume
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value \
    --secret-id "$SECRET_NAME" \
    --secret-string "$DB_URL" \
    --region "$REGION" >/dev/null
  echo "Secret updated: $SECRET_NAME"
else
  aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --secret-string "$DB_URL" \
    --region "$REGION" >/dev/null
  echo "Secret created: $SECRET_NAME"
fi

# 6) Authorize RDS SG to allow ingress from ECS service SG on 5432
SVC_SG_ID=$(aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters Name=group-name,Values=todo-svc-sg \
  --query 'SecurityGroups[0].GroupId' --output text)
RDS_SG_ID=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_ID" \
  --region "$REGION" \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
if [ -n "$SVC_SG_ID" ] && [ "$SVC_SG_ID" != "None" ] && [ -n "$RDS_SG_ID" ] && [ "$RDS_SG_ID" != "None" ]; then
  aws ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$RDS_SG_ID" \
    --protocol tcp --port 5432 \
    --source-group "$SVC_SG_ID" 2>/dev/null || true
  echo "Authorized SG ingress 5432 from $SVC_SG_ID to $RDS_SG_ID"
else
  echo "Warning: Could not resolve service or RDS security group; skipped SG rule"
fi
