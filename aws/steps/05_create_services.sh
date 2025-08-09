#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

VPC_ID=$(get_default_vpc)
# Build comma-separated subnet ids to satisfy ECS CLI format
SUBNETS_CSV=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=map-public-ip-on-launch,Values=true \
  --query 'join(`,`, Subnets[].SubnetId)' \
  --output text)
SVC_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=todo-svc-sg --query 'SecurityGroups[0].GroupId' --output text)
TG_BACKEND_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names todo-backend-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
TG_FRONTEND_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names todo-frontend-tg --query 'TargetGroups[0].TargetGroupArn' --output text)

create_service() {
  local name="$1" family="$2" container_name="$3" container_port="$4" tg_arn="$5"
  local status
  status=$(aws ecs describe-services --region "$REGION" --cluster todo-app-cluster --services "$name" --query 'services[0].status' --output text 2>/dev/null || echo "None")
  if [ -z "$status" ] || [ "$status" = "None" ] || [ "$status" = "INACTIVE" ]; then
    aws ecs create-service --region "$REGION" \
      --cluster todo-app-cluster \
      --service-name "$name" \
      --task-definition "$family" \
      --desired-count 0 \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS_CSV],securityGroups=[$SVC_SG_ID],assignPublicIp=ENABLED}" \
      --load-balancers "targetGroupArn=$tg_arn,containerName=$container_name,containerPort=$container_port" >/dev/null
    echo "Created service: $name"
  else
    echo "Service already exists: $name ($status)"
  fi
}

create_service "todo-backend-service" "todo-backend" "backend" 5678 "$TG_BACKEND_ARN"
create_service "todo-frontend-service" "todo-frontend" "frontend" 4567 "$TG_FRONTEND_ARN"

echo "Services ensured (desired-count=0): todo-backend-service, todo-frontend-service"
