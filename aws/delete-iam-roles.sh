#!/usr/bin/env bash

# Delete specific IAM roles by name (best-effort):
# - Detach inline and managed policies
# - Then delete the role
#
# Usage:
#   ./delete-iam-roles.sh <roleName1> [roleName2 ...]
#
# Notes:
# - This is destructive. Make sure roles are not used elsewhere.
# - Idempotent best-effort: missing resources are skipped.

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <roleName1> [roleName2 ...]" >&2
  exit 1
fi

for ROLE in "$@"; do
  echo "---"
  echo "Processing role: $ROLE"

  # Check if role exists
  if ! aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
    echo "Role not found: $ROLE (skip)"
    continue
  fi

  # Detach managed policies
  MAP=$(aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
  if [[ -n "$MAP" ]]; then
    for arn in $MAP; do
      echo "Detaching managed policy: $arn"
      aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$arn" >/dev/null 2>&1 || true
    done
  fi

  # Delete inline policies
  INLINES=$(aws iam list-role-policies --role-name "$ROLE" --query 'PolicyNames[]' --output text 2>/dev/null || echo "")
  if [[ -n "$INLINES" ]]; then
    for name in $INLINES; do
      echo "Deleting inline policy: $name"
      aws iam delete-role-policy --role-name "$ROLE" --policy-name "$name" >/dev/null 2>&1 || true
    done
  fi

  # Delete instance profiles that reference the role
  IPS=$(aws iam list-instance-profiles-for-role --role-name "$ROLE" --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo "")
  if [[ -n "$IPS" ]]; then
    for ip in $IPS; do
      echo "Removing role from instance profile: $ip"
      aws iam remove-role-from-instance-profile --instance-profile-name "$ip" --role-name "$ROLE" >/dev/null 2>&1 || true
      echo "Deleting instance profile: $ip"
      aws iam delete-instance-profile --instance-profile-name "$ip" >/dev/null 2>&1 || true
    done
  fi

  # Finally delete the role
  echo "Deleting role: $ROLE"
  aws iam delete-role --role-name "$ROLE" >/dev/null 2>&1 || echo "Failed to delete role (check dependencies): $ROLE"
done

echo "Done."


