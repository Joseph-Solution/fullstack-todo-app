#!/usr/bin/env bash

# Phase C2: Create ECS services (desired-count=0)

set -euo pipefail

ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }

get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//'; }

REGION=$(get_env AWS_REGION)
CLUSTER=$(get_env ECS_CLUSTER_NAME)
SVC_BACK=$(get_env ECS_BACKEND_SERVICE_NAME)
SVC_FRONT=$(get_env ECS_FRONTEND_SERVICE_NAME)

echo "Region: $REGION"
echo "Cluster: $CLUSTER"
echo "Services: $SVC_BACK, $SVC_FRONT"

# Network
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNETS_CSV=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=map-public-ip-on-launch,Values=true --query 'join(`,`, Subnets[].SubnetId)' --output text)
SVC_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=todo-svc-sg --query 'SecurityGroups[0].GroupId' --output text)

# Target groups
TG_BACK_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$(get_env TG_BACKEND_NAME)" --query 'TargetGroups[0].TargetGroupArn' --output text)
TG_FRONT_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$(get_env TG_FRONTEND_NAME)" --query 'TargetGroups[0].TargetGroupArn' --output text)

create_service() {
  local name="$1" family="$2" container_name="$3" container_port="$4" tg_arn="$5"
  local status
  status=$(aws ecs describe-services --region "$REGION" --cluster "$CLUSTER" --services "$name" --query 'services[0].status' --output text 2>/dev/null || echo "None")
  if [ -z "$status" ] || [ "$status" = "None" ] || [ "$status" = "INACTIVE" ]; then
    echo "Creating service: $name"
    aws ecs create-service --region "$REGION" \
      --cluster "$CLUSTER" \
      --service-name "$name" \
      --task-definition "$family" \
      --desired-count 0 \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS_CSV],securityGroups=[$SVC_SG_ID],assignPublicIp=ENABLED}" \
      --load-balancers "targetGroupArn=$tg_arn,containerName=$container_name,containerPort=$container_port" >/dev/null
  else
    echo "Exists: $name ($status)"
  fi
}

create_service "$SVC_BACK" "todo-backend" "backend" 5678 "$TG_BACK_ARN"
create_service "$SVC_FRONT" "todo-frontend" "frontend" 4567 "$TG_FRONT_ARN"

echo "Phase C2 completed."


