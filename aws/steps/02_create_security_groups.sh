#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

VPC_ID=$(get_default_vpc)
ALB_SG_ID=$(get_or_create_sg "$VPC_ID" "todo-alb-sg" "ALB security group for todo app")
SVC_SG_ID=$(get_or_create_sg "$VPC_ID" "todo-svc-sg" "Service security group for todo app")

# ALB: allow 80 from anywhere, allow all egress
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$ALB_SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 2>/dev/null || true
aws ec2 authorize-security-group-egress  --region "$REGION" --group-id "$ALB_SG_ID" --ip-permissions IpProtocol=-1,IpRanges='[{CidrIp=0.0.0.0/0}]' 2>/dev/null || true

# Service: allow 4567/5678 from ALB SG, allow all egress
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SVC_SG_ID" --ip-permissions '[{"IpProtocol":"tcp","FromPort":4567,"ToPort":4567,"UserIdGroupPairs":[{"GroupId":"'"$ALB_SG_ID"'"}]}]' 2>/dev/null || true
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SVC_SG_ID" --ip-permissions '[{"IpProtocol":"tcp","FromPort":5678,"ToPort":5678,"UserIdGroupPairs":[{"GroupId":"'"$ALB_SG_ID"'"}]}]' 2>/dev/null || true
aws ec2 authorize-security-group-egress  --region "$REGION" --group-id "$SVC_SG_ID" --ip-permissions IpProtocol=-1,IpRanges='[{CidrIp=0.0.0.0/0}]' 2>/dev/null || true

echo "ALB_SG_ID=$ALB_SG_ID"
echo "SVC_SG_ID=$SVC_SG_ID"
