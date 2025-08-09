#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

VPC_ID=$(get_default_vpc)
SUBNETS=$(get_public_subnets "$VPC_ID")
ALB_SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values=todo-alb-sg --query 'SecurityGroups[0].GroupId' --output text)

ALB_ARN=$(aws elbv2 describe-load-balancers --region "$REGION" --names todo-app-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" = "None" ]; then
  ALB_ARN=$(aws elbv2 create-load-balancer --region "$REGION" --name todo-app-alb --subnets $SUBNETS --security-groups "$ALB_SG_ID" --scheme internet-facing --type application --ip-address-type ipv4 --query 'LoadBalancers[0].LoadBalancerArn' --output text)
fi
ALB_DNS=$(aws elbv2 describe-load-balancers --region "$REGION" --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[0].DNSName' --output text)

TG_BACKEND_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names todo-backend-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
if [ -z "$TG_BACKEND_ARN" ] || [ "$TG_BACKEND_ARN" = "None" ]; then
  TG_BACKEND_ARN=$(aws elbv2 create-target-group --region "$REGION" --name todo-backend-tg --protocol HTTP --port 5678 --vpc-id "$VPC_ID" --target-type ip --health-check-protocol HTTP --health-check-path /health --health-check-port traffic-port --matcher HttpCode=200-399 --query 'TargetGroups[0].TargetGroupArn' --output text)
fi

TG_FRONTEND_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names todo-frontend-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
if [ -z "$TG_FRONTEND_ARN" ] || [ "$TG_FRONTEND_ARN" = "None" ]; then
  TG_FRONTEND_ARN=$(aws elbv2 create-target-group --region "$REGION" --name todo-frontend-tg --protocol HTTP --port 4567 --vpc-id "$VPC_ID" --target-type ip --health-check-protocol HTTP --health-check-path / --health-check-port traffic-port --matcher HttpCode=200-399 --query 'TargetGroups[0].TargetGroupArn' --output text)
fi

LISTENER_ARN=$(aws elbv2 describe-listeners --region "$REGION" --load-balancer-arn "$ALB_ARN" --query 'Listeners[?Port==`80`].ListenerArn | [0]' --output text 2>/dev/null || echo "")
if [ -z "$LISTENER_ARN" ] || [ "$LISTENER_ARN" = "None" ]; then
  LISTENER_ARN=$(aws elbv2 create-listener --region "$REGION" --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn="$TG_FRONTEND_ARN" --query 'Listeners[0].ListenerArn' --output text)
else
  aws elbv2 modify-listener --region "$REGION" --listener-arn "$LISTENER_ARN" --default-actions Type=forward,TargetGroupArn="$TG_FRONTEND_ARN" >/dev/null 2>&1 || true
fi

EXIST_RULE=$(aws elbv2 describe-rules --region "$REGION" --listener-arn "$LISTENER_ARN" --query 'Rules[?contains(Conditions[0].Values[0], `/api/*`)].RuleArn | [0]' --output text 2>/dev/null || echo "")
if [ -n "$EXIST_RULE" ] && [ "$EXIST_RULE" != "None" ]; then
  aws elbv2 delete-rule --region "$REGION" --rule-arn "$EXIST_RULE" || true
fi
aws elbv2 create-rule --region "$REGION" --listener-arn "$LISTENER_ARN" --priority 10 --conditions Field=path-pattern,Values=/api/* --actions Type=forward,TargetGroupArn="$TG_BACKEND_ARN" >/dev/null

echo "ALB_DNS=http://$ALB_DNS"
echo "TG_BACKEND_ARN=$TG_BACKEND_ARN"
echo "TG_FRONTEND_ARN=$TG_FRONTEND_ARN"
