#!/usr/bin/env bash

# Cleanup specific security groups by name in the default VPC of a region.
# Steps per group:
# 1) Revoke all ingress/egress rules on the group itself
# 2) Revoke any rules in other SGs that reference this group
# 3) Attempt to delete the group; if still in use, list referencing ENIs
#
# Usage:
#   REGION=ap-southeast-2 ./cleanup-security-groups.sh [sg-name ...]
# Defaults:
#   REGION: ${REGION:-${AWS_REGION:-ap-southeast-2}}
#   SG names: todo-app-sg todo-svc-sg

set -euo pipefail

REGION=${REGION:-${AWS_REGION:-ap-southeast-2}}

echo "Region: $REGION"

# Resolve default VPC in the region
VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || echo "None")

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  echo "No default VPC found in region $REGION" >&2
  exit 1
fi

echo "Default VPC: $VPC_ID"

TARGET_SG_NAMES=("${@:-}")
if [[ ${#TARGET_SG_NAMES[@]} -eq 0 || -z "${TARGET_SG_NAMES[0]}" ]]; then
  TARGET_SG_NAMES=("todo-app-sg" "todo-svc-sg")
fi

delete_sg_safely() {
  local sg_name="$1"
  local sg_id
  echo "---"
  # Do not touch default
  if [[ "$sg_name" == "default" ]]; then
    echo "Skip default SG by policy"
    return 0
  fi

  sg_id=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$sg_name" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || echo "None")

  echo "Target: $sg_name ($sg_id)"
  if [[ -z "$sg_id" || "$sg_id" == "None" ]]; then
    echo "Not found. Skipping."
    return 0
  fi

  # 1) Revoke rules on the group itself by rule-id (egress first, then ingress)
  local ids_eg ids_in
  ids_eg=$(aws ec2 describe-security-group-rules \
    --region "$REGION" \
    --filters Name=group-id,Values="$sg_id" Name=is-egress,Values=true \
    --query 'SecurityGroupRules[].SecurityGroupRuleId' \
    --output text 2>/dev/null || true)
  if [[ -n "${ids_eg:-}" ]]; then
    echo "Revoking egress rules on $sg_id"
    aws ec2 revoke-security-group-egress --region "$REGION" --group-id "$sg_id" --security-group-rule-ids $ids_eg >/dev/null 2>&1 || true
  fi

  ids_in=$(aws ec2 describe-security-group-rules \
    --region "$REGION" \
    --filters Name=group-id,Values="$sg_id" Name=is-egress,Values=false \
    --query 'SecurityGroupRules[].SecurityGroupRuleId' \
    --output text 2>/dev/null || true)
  if [[ -n "${ids_in:-}" ]]; then
    echo "Revoking ingress rules on $sg_id"
    aws ec2 revoke-security-group-ingress --region "$REGION" --group-id "$sg_id" --security-group-rule-ids $ids_in >/dev/null 2>&1 || true
  fi

  # 2) Revoke any rules in other SGs referencing this group
  echo "Scanning other SGs in VPC for references to $sg_id..."
  local all_gids gids_txt
  gids_txt=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" \
    --query 'SecurityGroups[].GroupId' \
    --output text 2>/dev/null || echo "")
  for gid in $gids_txt; do
    # Skip self
    [[ "$gid" == "$sg_id" ]] && continue
    local pairs
    pairs=$(aws ec2 describe-security-group-rules \
      --region "$REGION" \
      --filters Name=group-id,Values="$gid" \
      --query "SecurityGroupRules[?ReferencedGroupInfo.GroupId==\`$sg_id\`].[SecurityGroupRuleId,IsEgress]" \
      --output text 2>/dev/null || echo "")
    if [[ -n "${pairs:-}" ]]; then
      echo "Revoking rules in $gid referencing $sg_id"
      # Each line: <ruleId> <True|False>
      while read -r rid egress_flag; do
        [[ -z "$rid" ]] && continue
        if [[ "$egress_flag" == "True" ]]; then
          aws ec2 revoke-security-group-egress --region "$REGION" --group-id "$gid" --security-group-rule-ids "$rid" >/dev/null 2>&1 || true
        else
          aws ec2 revoke-security-group-ingress --region "$REGION" --group-id "$gid" --security-group-rule-ids "$rid" >/dev/null 2>&1 || true
        fi
      done <<< "$pairs"
    fi
  done

  # 3) Attempt delete; if fails due to dependency, list ENIs using it
  echo "Deleting SG: $sg_id ($sg_name)"
  if aws ec2 delete-security-group --group-id "$sg_id" --region "$REGION" >/dev/null 2>&1; then
    echo "Deleted: $sg_name"
  else
    echo "Still InUse. ENIs referencing $sg_name:"
    aws ec2 describe-network-interfaces \
      --region "$REGION" \
      --filters Name=group-id,Values="$sg_id" \
      --query 'NetworkInterfaces[].{id:NetworkInterfaceId,status:Status,desc:Description,attach:Attachment.InstanceId,subnet:SubnetId}' \
      --output table || true
  fi
}

# Process each target SG name
for name in "${TARGET_SG_NAMES[@]}"; do
  delete_sg_safely "$name"
done

echo "Done."


