#!/usr/bin/env bash

# Create a PostgreSQL RDS instance and write DATABASE_URL to .env and Secrets Manager.
#
# Usage:
#   REGION=ap-southeast-2 ./create-rds.sh
# Options via env:
#   DB_IDENTIFIER: default todo-db-instance
#   DB_ENGINE_VERSION: default 15.4
#   DB_INSTANCE_CLASS: default db.t4g.micro
#   DB_STORAGE_GB: default 20
#   DB_NAME: default tododb
#   DB_MASTER_USERNAME: default postgres
#   DB_MASTER_PASSWORD: if empty, a strong random password will be generated
#   PUBLICLY_ACCESSIBLE: default false
#   WAIT: default true (wait until available)
#   SECRET_NAME: default todo-database-url
#
# Requirements:
# - Default VPC and subnet group should exist; otherwise, create a subnet group first

set -euo pipefail

REGION=${REGION:-${AWS_REGION:-ap-southeast-2}}
ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"

DB_IDENTIFIER=${DB_IDENTIFIER:-todo-db-instance}
DB_ENGINE_VERSION=${DB_ENGINE_VERSION:-auto}
DB_INSTANCE_CLASS=${DB_INSTANCE_CLASS:-db.t4g.micro}
DB_STORAGE_GB=${DB_STORAGE_GB:-20}
DB_NAME=${DB_NAME:-tododb}
DB_MASTER_USERNAME=${DB_MASTER_USERNAME:-postgres}
DB_MASTER_PASSWORD=${DB_MASTER_PASSWORD:-}
PUBLICLY_ACCESSIBLE=${PUBLICLY_ACCESSIBLE:-false}
WAIT=${WAIT:-true}
SECRET_NAME=${SECRET_NAME:-todo-database-url}

echo "Region: $REGION"
echo "RDS identifier: $DB_IDENTIFIER"

if [[ -z "$DB_MASTER_PASSWORD" ]]; then
  # Generate a strong random password (32 chars)
  DB_MASTER_PASSWORD=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9!@#$%^&*()_+-' | head -c32)
  echo "Generated a strong master password (will not print)"
fi

echo "Creating RDS instance (this may take several minutes)..."

# Resolve engine version if set to auto
ENGINE_VERSION_OPT=()
if [[ "$DB_ENGINE_VERSION" == "auto" ]]; then
  DEF_VER=$(aws rds describe-db-engine-versions --region "$REGION" --engine postgres --default-only --query 'DBEngineVersions[0].EngineVersion' --output text 2>/dev/null || echo "")
  if [[ -n "$DEF_VER" && "$DEF_VER" != "None" ]]; then
    echo "Using default Postgres engine version: $DEF_VER"
    ENGINE_VERSION_OPT=(--engine-version "$DEF_VER")
  else
    echo "No default engine version found; letting AWS choose"
    ENGINE_VERSION_OPT=()
  fi
else
  ENGINE_VERSION_OPT=(--engine-version "$DB_ENGINE_VERSION")
fi

# Boolean flags must use --flag / --no-flag format
PUB_FLAG="--no-publicly-accessible"
if [[ "$PUBLICLY_ACCESSIBLE" == "true" ]]; then
  PUB_FLAG="--publicly-accessible"
fi

aws rds create-db-instance \
  --region "$REGION" \
  --db-instance-identifier "$DB_IDENTIFIER" \
  --db-instance-class "$DB_INSTANCE_CLASS" \
  --engine postgres \
  "${ENGINE_VERSION_OPT[@]}" \
  --allocated-storage "$DB_STORAGE_GB" \
  --db-name "$DB_NAME" \
  --master-username "$DB_MASTER_USERNAME" \
  --master-user-password "$DB_MASTER_PASSWORD" \
  $PUB_FLAG \
  --backup-retention-period 0 \
  --no-multi-az \
  --storage-type gp2 \
  --no-deletion-protection >/dev/null

if [[ "$WAIT" == "true" ]]; then
  echo "Waiting for RDS instance to become available..."
  aws rds wait db-instance-available --region "$REGION" --db-instance-identifier "$DB_IDENTIFIER"
fi

echo "Fetching endpoint..."
EP=$(aws rds describe-db-instances --region "$REGION" --db-instance-identifier "$DB_IDENTIFIER" --query 'DBInstances[0].Endpoint.Address' --output text)
PORT=$(aws rds describe-db-instances --region "$REGION" --db-instance-identifier "$DB_IDENTIFIER" --query 'DBInstances[0].Endpoint.Port' --output text)

DB_URL="postgresql://${DB_MASTER_USERNAME}:${DB_MASTER_PASSWORD}@${EP}:${PORT}/${DB_NAME}"

echo "Upserting secret in Secrets Manager: $SECRET_NAME (redacted preview)"
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  aws secretsmanager put-secret-value --secret-id "$SECRET_NAME" --secret-string "$DB_URL" --region "$REGION" >/dev/null
else
  aws secretsmanager create-secret --name "$SECRET_NAME" --secret-string "$DB_URL" --region "$REGION" >/dev/null
fi

echo "Writing DATABASE_URL into .env (redacted)"
sed -i '/^DATABASE_URL=/d' "$ENV_FILE" 2>/dev/null || true
printf 'DATABASE_URL="%s"\n' "$DB_URL" >> "$ENV_FILE"
sed -E 's#^(DATABASE_URL=").*("$)#\1***redacted***\2#' "$ENV_FILE" | sed -n 's/^DATABASE_URL=.*/&/p'

echo "RDS created. Endpoint: $EP:$PORT"
echo "Note: authorize your service SG (todo-svc-sg) to access port 5432 after SGs are created."

echo "Done."


