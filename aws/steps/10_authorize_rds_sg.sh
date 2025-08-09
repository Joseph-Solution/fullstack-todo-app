#!/usr/bin/env bash
set -euo pipefail

REGION=${REGION:-ap-southeast-2}
DB_ID=${DB_ID:-todo-db-instance}
SVC_SG_NAME=${SVC_SG_NAME:-todo-svc-sg}

# Get service SG id
SVC_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=group-name,Values="$SVC_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
if [ -z "$SVC_SG_ID" ] || [ "$SVC_SG_ID" = "None" ]; then
  echo "Service SG not found: $SVC_SG_NAME" >&2
  exit 1
fi
# Get RDS SG id
RDS_SG_ID=$(aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region "$REGION" --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
if [ -z "$RDS_SG_ID" ] || [ "$RDS_SG_ID" = "None" ]; then
  echo "RDS SG not found for DB: $DB_ID" >&2
  exit 1
fi
# Authorize 5432 inbound from service SG
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$RDS_SG_ID" --protocol tcp --port 5432 --source-group "$SVC_SG_ID" 2>/dev/null || true

echo "Authorized inbound 5432 from $SVC_SG_ID to RDS SG $RDS_SG_ID"
