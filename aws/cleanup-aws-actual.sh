#!/usr/bin/env bash

# AWS cleanup script for this project (idempotent)
# Usage: ./cleanup-aws-actual.sh

set -euo pipefail

echo "Starting AWS cleanup..."

# Configuration based on detected resources
REGION="ap-southeast-2"
ACCOUNT_ID="248729599833"
ECR_REPOSITORY="joseph-solution/fullstack-todo-app"

# Target ECS clusters to clean (as detected)
TARGET_CLUSTERS=("todo-app-cluster" "-")

echo "Region: $REGION"
echo "Account: $ACCOUNT_ID"

# Helper: check if cluster exists
cluster_exists() {
  local name="$1"
  aws ecs describe-clusters \
    --region "$REGION" \
    --clusters "$name" \
    --query 'clusters[0].status' \
    --output text 2>/dev/null | grep -qE 'ACTIVE|INACTIVE'
}

# 1) Delete ECS services in target clusters
echo "Deleting ECS services..."
for cluster in "${TARGET_CLUSTERS[@]}"; do
  if cluster_exists "$cluster"; then
    echo "- Cluster: $cluster"
    services=$(aws ecs list-services --cluster "$cluster" --region "$REGION" --query 'serviceArns[]' --output text 2>/dev/null || echo "")
    if [ -n "${services:-}" ]; then
      for svc_arn in $services; do
        svc_name=$(echo "$svc_arn" | awk -F'/' '{print $NF}')
        echo "  · Draining and deleting service: $svc_name"
        # Set desired count to 0, wait stable, then delete
        aws ecs update-service --cluster "$cluster" --service "$svc_name" --desired-count 0 --region "$REGION" >/dev/null 2>&1 || true
        aws ecs wait services-stable --cluster "$cluster" --services "$svc_name" --region "$REGION" >/dev/null 2>&1 || true
        aws ecs delete-service --cluster "$cluster" --service "$svc_name" --force --region "$REGION" >/dev/null 2>&1 || true
      done
    else
      echo "  · No services in cluster"
    fi
  else
    echo "- Cluster not found (skip): $cluster"
  fi
done

# 2) Delete ALB listeners, ALB, and Target Groups
echo "Deleting ALB/listeners/target groups..."
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$REGION" --names todo-app-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")
if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  echo "- Found ALB: $ALB_ARN"
  # Delete listeners first
  LISTENERS=$(aws elbv2 describe-listeners --region "$REGION" --load-balancer-arn "$ALB_ARN" --query 'Listeners[].ListenerArn' --output text 2>/dev/null || echo "")
  for lst in $LISTENERS; do
    echo "  · Deleting listener: $lst"
    aws elbv2 delete-listener --region "$REGION" --listener-arn "$lst" >/dev/null 2>&1 || true
  done
  # Delete ALB
  echo "- Deleting ALB todo-app-alb"
  aws elbv2 delete-load-balancer --region "$REGION" --load-balancer-arn "$ALB_ARN" >/dev/null 2>&1 || true
  # Wait a bit for dependencies to detach
  sleep 5
else
  echo "- ALB not found: todo-app-alb"
fi

# Delete target groups (backend and frontend)
for tg_name in todo-backend-tg todo-frontend-tg; do
  TG_ARN=$(aws elbv2 describe-target-groups --region "$REGION" --names "$tg_name" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
  if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
    echo "- Deleting target group: $tg_name"
    aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$TG_ARN" >/dev/null 2>&1 || true
  else
    echo "- Target group not found: $tg_name"
  fi
done

# 3) Delete ECS clusters
echo "Deleting ECS clusters..."
for cluster in "${TARGET_CLUSTERS[@]}"; do
  if cluster_exists "$cluster"; then
    echo "- Deleting cluster: $cluster"
    aws ecs delete-cluster --cluster "$cluster" --region "$REGION" >/dev/null 2>&1 || true
  else
    echo "- Cluster not found (skip): $cluster"
  fi
done

# 4) Deregister task definitions for known families
echo "Deregistering task definitions..."
for family in todo-backend todo-frontend; do
  td_arns=$(aws ecs list-task-definitions --region "$REGION" --family-prefix "$family" --query 'taskDefinitionArns[]' --output text 2>/dev/null || echo "")
  if [ -n "$td_arns" ]; then
    for td in $td_arns; do
      echo "- Deregister: $td"
      aws ecs deregister-task-definition --task-definition "$td" --region "$REGION" >/dev/null 2>&1 || true
    done
  else
    echo "- No task definitions for family: $family"
  fi
done

# 5) Clean ECR repository
echo "Cleaning ECR repository..."
if aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --region "$REGION" >/dev/null 2>&1; then
  echo "- Deleting all images in $ECR_REPOSITORY"
  image_ids=$(aws ecr list-images --repository-name "$ECR_REPOSITORY" --region "$REGION" --query 'imageIds[]' --output json 2>/dev/null || echo '[]')
  if [ "$image_ids" != "[]" ]; then
    aws ecr batch-delete-image --repository-name "$ECR_REPOSITORY" --image-ids "$image_ids" --region "$REGION" >/dev/null 2>&1 || true
  fi
  echo "- Deleting repository: $ECR_REPOSITORY"
  aws ecr delete-repository --repository-name "$ECR_REPOSITORY" --force --region "$REGION" >/dev/null 2>&1 || true
else
  echo "- ECR repository not found: $ECR_REPOSITORY"
fi

# 6) Delete Secrets Manager secret used by the app
echo "Deleting Secrets Manager secret..."
SECRET_NAME="todo-database-url"
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "- Deleting secret: $SECRET_NAME"
  aws secretsmanager delete-secret --secret-id "$SECRET_NAME" --force-delete-without-recovery --region "$REGION" >/dev/null 2>&1 || true
else
  echo "- Secret not found: $SECRET_NAME"
fi

# 7) Delete CloudWatch log groups
echo "Deleting CloudWatch log groups..."
for lg in /ecs/todo-backend /ecs/todo-frontend; do
  if aws logs describe-log-groups --log-group-name-prefix "$lg" --region "$REGION" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$lg"; then
    echo "- Deleting log group: $lg"
    aws logs delete-log-group --log-group-name "$lg" --region "$REGION" >/dev/null 2>&1 || true
  else
    echo "- Log group not found: $lg"
  fi
done

# 8) Delete security groups (after ALB/ENIs are gone)
echo "Deleting security groups..."
DEFAULT_VPC=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
if [ -n "$DEFAULT_VPC" ] && [ "$DEFAULT_VPC" != "None" ]; then
  for sg_name in todo-alb-sg todo-svc-sg; do
    SG_ID=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=vpc-id,Values="$DEFAULT_VPC" Name=group-name,Values="$sg_name" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
    if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
      echo "- Deleting security group: $sg_name ($SG_ID)"
      # Retry a few times in case ENIs are still releasing
      for i in {1..6}; do
        if aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION" >/dev/null 2>&1; then
          echo "  · Deleted: $sg_name"
          break
        else
          echo "  · In use, retrying in 5s ($i/6)"
          sleep 5
        fi
      done
    else
      echo "- Security group not found: $sg_name"
    fi
  done
else
  echo "- Default VPC not found; skip SG deletion"
fi

echo "Cleanup completed."
echo
echo "Next steps:"
echo "1) Run setup-aws.sh to recreate infrastructure"
echo "2) Reconfigure GitHub secrets if needed"
echo "3) Push to release branch to test"