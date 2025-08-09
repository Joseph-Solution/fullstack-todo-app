#!/usr/bin/env bash

# Delete an Application Load Balancer (ALB) by name, including:
# - All its listeners
# - The ALB itself
# - Any target groups attached to the ALB
#
# Usage:
#   REGION=ap-southeast-2 ./delete-alb.sh <ALB_NAME>
# Defaults:
#   REGION: ${REGION:-${AWS_REGION:-ap-southeast-2}}
#
# Notes:
# - Idempotent: if resources are missing, it skips.
# - Includes simple retries to handle eventual consistency.

set -euo pipefail

REGION=${REGION:-${AWS_REGION:-ap-southeast-2}}
ALB_NAME=${1:-}

if [[ -z "$ALB_NAME" ]]; then
  echo "Usage: REGION=ap-southeast-2 $0 <ALB_NAME>" >&2
  exit 1
fi

echo "Region: $REGION"
echo "Deleting ALB by name: $ALB_NAME"

# Find ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --names "$ALB_NAME" \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text 2>/dev/null || echo "None")

if [[ -z "$ALB_ARN" || "$ALB_ARN" == "None" ]]; then
  echo "ALB not found: $ALB_NAME (nothing to do)"
  exit 0
fi

echo "Found ALB ARN: $ALB_ARN"

# 1) Delete listeners
LISTENERS=$(aws elbv2 describe-listeners \
  --region "$REGION" \
  --load-balancer-arn "$ALB_ARN" \
  --query 'Listeners[].ListenerArn' \
  --output text 2>/dev/null || echo "")
if [[ -n "${LISTENERS:-}" ]]; then
  for lst in $LISTENERS; do
    echo "Deleting listener: $lst"
    aws elbv2 delete-listener --region "$REGION" --listener-arn "$lst" >/dev/null 2>&1 || true
  done
fi

# 2) Delete ALB
echo "Deleting ALB: $ALB_NAME"
aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$ALB_ARN" >/dev/null 2>&1 || true

# Wait a bit for resources to detach
sleep 5

# 3) Delete target groups attached to the ALB
for i in {1..5}; do
  TG_ARNS=$(aws elbv2 describe-target-groups \
    --region "$REGION" \
    --load-balancer-arn "$ALB_ARN" \
    --query 'TargetGroups[].TargetGroupArn' \
    --output text 2>/dev/null || echo "")
  if [[ -z "${TG_ARNS:-}" ]]; then
    echo "No target groups attached to ALB (done)"
    break
  fi
  for tg in $TG_ARNS; do
    echo "Deleting target group: $tg"
    aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$tg" >/dev/null 2>&1 || true
  done
  echo "Retry check for remaining target groups in 3s..."
  sleep 3
done

echo "ALB delete flow completed for: $ALB_NAME"


