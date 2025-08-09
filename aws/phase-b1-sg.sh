#!/usr/bin/env bash

# Phase B1: Create Security Groups for ALB and Services
# - ALB SG: allow 80 from 0.0.0.0/0, allow all egress
# - Service SG: allow 4567/5678 from ALB SG, allow all egress

set -euo pipefail

ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }
get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//'; }

REGION=$(get_env AWS_REGION)
ALB_SG_NAME=$(get_env ALB_SG_NAME)
SVC_SG_NAME=$(get_env SVC_SG_NAME)

echo "Region: $REGION"
echo "ALB_SG_NAME: $ALB_SG_NAME"
echo "SVC_SG_NAME: $SVC_SG_NAME"

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
echo "Default VPC: $VPC_ID"

get_or_create_sg() {
  local name="$1" desc="$2"
  local sg
  sg=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$name" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
  if [[ -z "$sg" || "$sg" == "None" ]]; then
    sg=$(aws ec2 create-security-group --region "$REGION" --group-name "$name" --description "$desc" --vpc-id "$VPC_ID" --query GroupId --output text)
  fi
  echo "$sg"
}

ALB_SG_ID=$(get_or_create_sg "$ALB_SG_NAME" "ALB security group for todo app")
SVC_SG_ID=$(get_or_create_sg "$SVC_SG_NAME" "Service security group for todo app")

echo "ALB_SG_ID=$ALB_SG_ID"
echo "SVC_SG_ID=$SVC_SG_ID"

# Authorize rules (idempotent best-effort)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$ALB_SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 >/dev/null 2>&1 || true
aws ec2 authorize-security-group-egress  --region "$REGION" --group-id "$ALB_SG_ID" --ip-permissions IpProtocol=-1,IpRanges='[{CidrIp=0.0.0.0/0}]' >/dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SVC_SG_ID" --ip-permissions '[{"IpProtocol":"tcp","FromPort":4567,"ToPort":4567,"UserIdGroupPairs":[{"GroupId":"'"$ALB_SG_ID"'"}]}]' >/dev/null 2>&1 || true
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SVC_SG_ID" --ip-permissions '[{"IpProtocol":"tcp","FromPort":5678,"ToPort":5678,"UserIdGroupPairs":[{"GroupId":"'"$ALB_SG_ID"'"}]}]' >/dev/null 2>&1 || true
aws ec2 authorize-security-group-egress  --region "$REGION" --group-id "$SVC_SG_ID" --ip-permissions IpProtocol=-1,IpRanges='[{CidrIp=0.0.0.0/0}]' >/dev/null 2>&1 || true

echo "Phase B1 completed."


