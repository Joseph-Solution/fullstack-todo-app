#!/usr/bin/env bash

# Delete ELBv2 target groups by name (exact or glob-like match).
# - Detaches are not required if the ALB/listeners are already removed
# - Includes small retries for eventual consistency
#
# Usage:
#   REGION=ap-southeast-2 ./delete-target-groups.sh <name_or_glob> [more...]
# Examples:
#   REGION=ap-southeast-2 ./delete-target-groups.sh todo-app-*-tg
#   REGION=ap-southeast-2 ./delete-target-groups.sh todo-app-backend-tg todo-app-tg
# Defaults (if no args provided):
#   names: todo-*-tg todo-backend-tg todo-frontend-tg

set -euo pipefail

REGION=${REGION:-${AWS_REGION:-ap-southeast-2}}

echo "Region: $REGION"

if [[ $# -gt 0 ]]; then
  TARGET_PATTERNS=("$@")
else
  TARGET_PATTERNS=("todo-*-tg" "todo-backend-tg" "todo-frontend-tg")
fi

echo "Patterns: ${TARGET_PATTERNS[*]}"

# Build list of target group names to delete (resolve patterns safely)
all_names=()
mapfile -t all_names < <(aws elbv2 describe-target-groups \
  --region "$REGION" \
  --query 'TargetGroups[].TargetGroupName' \
  --output text 2>/dev/null | tr '\t' '\n' || true)

declare -A name_set=()
for pat in "${TARGET_PATTERNS[@]}"; do
  if [[ "$pat" == *'*'* || "$pat" == *'?'* ]]; then
    for n in "${all_names[@]}"; do
      [[ -z "$n" ]] && continue
      if [[ "$n" == $pat ]]; then name_set["$n"]=1; fi
    done
  else
    name_set["$pat"]=1
  fi
done

to_delete_names=()
for n in "${!name_set[@]}"; do to_delete_names+=("$n"); done

if [[ ${#to_delete_names[@]} -eq 0 ]]; then
  echo "No target groups matched. Nothing to delete."
  exit 0
fi

echo "Will delete target groups by name: ${to_delete_names[*]}"

for name in "${to_delete_names[@]}"; do
  arn=$(aws elbv2 describe-target-groups \
    --region "$REGION" \
    --names "$name" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || echo "None")
  if [[ -z "$arn" || "$arn" == "None" ]]; then
    echo "Skip (not found): $name"
    continue
  fi
  echo "Deleting target group: $name ($arn)"
  deleted=false
  for i in {1..5}; do
    if aws elbv2 delete-target-group --region "$REGION" --target-group-arn "$arn" >/dev/null 2>&1; then
      echo "  Deleted $name"
      deleted=true
      break
    else
      echo "  InUse or transient error, retry $i/5 in 3s..."
      sleep 3
    fi
  done
  if ! $deleted; then
    echo "  Failed to delete $name after retries"
  fi
done

echo "Done."


