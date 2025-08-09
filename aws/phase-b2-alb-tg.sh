#!/usr/bin/env bash

# Phase B2: Create ALB and Target Groups

set -euo pipefail

ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }
get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//'; }

REGION=$(get_env AWS_REGION)
ALB_NAME=$(get_env ALB_NAME)
TG_FRONT=$(get_env TG_FRONTEND_NAME)
TG_BACK=$(get_env TG_BACKEND_NAME)
FRONTEND_PORT=$(get_env FRONTEND_PORT)
BACKEND_PORT=$(get_env BACKEND_PORT)

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
SUBNETS=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=map-public-ip-on-launch,Values=true --query 'Subnets[].SubnetId' --output text)
ALB_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=todo-alb-sg --query 'SecurityGroups[0].GroupId' --output text)

echo "Region: $REGION"
echo "ALB_NAME: $ALB_NAME"
echo "VPC: $VPC_ID"
echo "ALB_SG_ID: $ALB_SG_ID"

ALB_ARN=$(aws elbv2 describe-load-balancers --region "$REGION" --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")
if [[ -z "$ALB_ARN" || "$ALB_ARN" == "None" ]]; then
  ALB_ARN=$(aws elbv2 create-load-balancer --region "$REGION" --name "$ALB_NAME" --subnets $SUBNETS --security-groups "$ALB_SG_ID" --scheme internet-facing --type application --ip-address-type ipv4 --query 'LoadBalancers[0].LoadBalancerArn' --output text)
fi
ALB_DNS=$(aws elbv2 describe-load-balancers --region "$REGION" --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text)

TG_BACK_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$TG_BACK" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
if [[ -z "$TG_BACK_ARN" || "$TG_BACK_ARN" == "None" ]]; then
  TG_BACK_ARN=$(aws elbv2 create-target-group --region "$REGION" --name "$TG_BACK" --protocol HTTP --port "$BACKEND_PORT" --vpc-id "$VPC_ID" --target-type ip --health-check-protocol HTTP --health-check-path /health --health-check-port traffic-port --matcher HttpCode=200-399 --query 'TargetGroups[0].TargetGroupArn' --output text)
fi

TG_FRONT_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$TG_FRONT" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
if [[ -z "$TG_FRONT_ARN" || "$TG_FRONT_ARN" == "None" ]]; then
  TG_FRONT_ARN=$(aws elbv2 create-target-group --region "$REGION" --name "$TG_FRONT" --protocol HTTP --port "$FRONTEND_PORT" --vpc-id "$VPC_ID" --target-type ip --health-check-protocol HTTP --health-check-path / --health-check-port traffic-port --matcher HttpCode=200-399 --query 'TargetGroups[0].TargetGroupArn' --output text)
fi

echo "ALB_ARN=$ALB_ARN"
echo "ALB_DNS=http://$ALB_DNS"
echo "TG_BACK_ARN=$TG_BACK_ARN"
echo "TG_FRONT_ARN=$TG_FRONT_ARN"

echo "Phase B2 completed."


