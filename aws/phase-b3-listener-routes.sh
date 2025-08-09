#!/usr/bin/env bash

# Phase B3: Create Listener and /api route

set -euo pipefail

ROOT_DIR="/home/devuser/Documents/my-projects/fullstack-todo-app"
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }
get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//'; }

REGION=$(get_env AWS_REGION)
ALB_NAME=$(get_env ALB_NAME)
TG_FRONT=$(get_env TG_FRONTEND_NAME)
TG_BACK=$(get_env TG_BACKEND_NAME)

ALB_ARN=$(aws elbv2 describe-load-balancers --region "$REGION" --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text)
TG_FRONT_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$TG_FRONT" --query 'TargetGroups[0].TargetGroupArn' --output text)
TG_BACK_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$TG_BACK" --query 'TargetGroups[0].TargetGroupArn' --output text)

LISTENER_ARN=$(aws elbv2 describe-listeners --region "$REGION" --load-balancer-arn "$ALB_ARN" --query 'Listeners[?Port==`80`].ListenerArn | [0]' --output text 2>/dev/null || echo "None")
if [[ -z "$LISTENER_ARN" || "$LISTENER_ARN" == "None" ]]; then
  LISTENER_ARN=$(aws elbv2 create-listener --region "$REGION" --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn="$TG_FRONT_ARN" --query 'Listeners[0].ListenerArn' --output text)
else
  aws elbv2 modify-listener --region "$REGION" --listener-arn "$LISTENER_ARN" --default-actions Type=forward,TargetGroupArn="$TG_FRONT_ARN" >/dev/null 2>&1 || true
fi

EXIST_RULE=$(aws elbv2 describe-rules --region "$REGION" --listener-arn "$LISTENER_ARN" --query 'Rules[?contains(Conditions[0].Values[0], `/api/*`)].RuleArn | [0]' --output text 2>/dev/null || echo "None")
if [[ -n "$EXIST_RULE" && "$EXIST_RULE" != "None" ]]; then
  aws elbv2 delete-rule --region "$REGION" --rule-arn "$EXIST_RULE" || true
fi
aws elbv2 create-rule --region "$REGION" --listener-arn "$LISTENER_ARN" --priority 10 --conditions Field=path-pattern,Values=/api/* --actions Type=forward,TargetGroupArn="$TG_BACK_ARN" >/dev/null

echo "LISTENER_ARN=$LISTENER_ARN"
echo "Phase B3 completed."


