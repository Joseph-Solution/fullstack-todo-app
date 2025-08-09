#!/usr/bin/env bash

# Phase B4: Authorize ECS service SG to access RDS (5432)

set -euo pipefail

ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }
get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//'; }

REGION=$(get_env AWS_REGION)
DB_ID=${DB_IDENTIFIER:-todo-db-instance}

echo "Region: $REGION"
echo "DB: $DB_ID"

# Find RDS VPC security group(s)
RDS_SG_IDS=$(aws rds describe-db-instances --region "$REGION" --db-instance-identifier "$DB_ID" --query 'DBInstances[0].VpcSecurityGroups[].VpcSecurityGroupId' --output text)
if [[ -z "$RDS_SG_IDS" ]]; then
  echo "No RDS SGs found for $DB_ID" >&2
  exit 1
fi

# Find service SG
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SVC_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=todo-svc-sg --query 'SecurityGroups[0].GroupId' --output text)
echo "RDS_SG_IDS=$RDS_SG_IDS"
echo "SVC_SG_ID=$SVC_SG_ID"

for rds_sg in $RDS_SG_IDS; do
  # Authorize ingress 5432 from service SG (idempotent)
  aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$rds_sg" --protocol tcp --port 5432 --source-group "$SVC_SG_ID" >/dev/null 2>&1 || true
  echo "Authorized 5432 from $SVC_SG_ID into $rds_sg"
done

echo "Phase B4 completed."


