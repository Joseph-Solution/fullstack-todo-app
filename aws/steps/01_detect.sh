#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

ACCOUNT_ID=$(get_account_id)
CURRENT_REGION=$REGION

echo "Region: $CURRENT_REGION"
echo "Account: $ACCOUNT_ID"

echo "--- ECS Clusters ---"
aws ecs list-clusters --region "$CURRENT_REGION" --query 'clusterArns[]' --output text || true

echo "--- ECS Services per Cluster ---"
for cluster in $(aws ecs list-clusters --region "$CURRENT_REGION" --query 'clusterArns[]' --output text || true); do
  name=${cluster##*/}
  echo "Cluster: $name"
  aws ecs list-services --cluster "$name" --region "$CURRENT_REGION" --query 'serviceArns[]' --output text || true
done

echo "--- ECR Repositories ---"
aws ecr describe-repositories --region "$CURRENT_REGION" --query 'repositories[].repositoryName' --output text || true
