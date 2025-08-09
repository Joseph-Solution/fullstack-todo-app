#!/usr/bin/env bash
set -euo pipefail

# Default region; override by exporting REGION before running scripts
REGION=${REGION:-ap-southeast-2}

get_account_id() {
  aws sts get-caller-identity --query Account --output text
}

get_default_vpc() {
  aws ec2 describe-vpcs \
    --region "$REGION" \
    --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' \
    --output text
}

get_public_subnets() {
  local vpc_id="$1"
  aws ec2 describe-subnets \
    --region "$REGION" \
    --filters Name=vpc-id,Values="$vpc_id" Name=map-public-ip-on-launch,Values=true \
    --query 'Subnets[].SubnetId' \
    --output text
}

get_or_create_sg() {
  local vpc_id="$1" name="$2" desc="$3"
  local sg_id
  sg_id=$(aws ec2 describe-security-groups \
            --region "$REGION" \
            --filters Name=vpc-id,Values="$vpc_id" Name=group-name,Values="$name" \
            --query 'SecurityGroups[0].GroupId' \
            --output text 2>/dev/null || true)
  if [ -z "$sg_id" ] || [ "$sg_id" = "None" ]; then
    sg_id=$(aws ec2 create-security-group \
              --region "$REGION" \
              --group-name "$name" \
              --description "$desc" \
              --vpc-id "$vpc_id" \
              --query GroupId \
              --output text)
  fi
  echo "$sg_id"
}
