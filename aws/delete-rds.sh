#!/usr/bin/env bash

# Delete an RDS DB instance by identifier.
#
# Usage:
#   REGION=ap-southeast-2 ./delete-rds.sh <DB_INSTANCE_IDENTIFIER>
#
# Defaults:
#   REGION: ${REGION:-${AWS_REGION:-ap-southeast-2}}
#   SKIP_FINAL_SNAPSHOT: ${SKIP_FINAL_SNAPSHOT:-true}
#   FINAL_SNAPSHOT_ID: ${FINAL_SNAPSHOT_ID:-db-final-$(date +%Y%m%d-%H%M%S)}
#   WAIT: ${WAIT:-true} (wait for instance deletion to complete)
#
# Notes:
# - If SKIP_FINAL_SNAPSHOT=true (default), the instance will be deleted without a snapshot.
# - If you want a snapshot, set SKIP_FINAL_SNAPSHOT=false and optionally set FINAL_SNAPSHOT_ID.

set -euo pipefail

REGION=${REGION:-${AWS_REGION:-ap-southeast-2}}
DB_ID=${1:-}
SKIP_FINAL_SNAPSHOT=${SKIP_FINAL_SNAPSHOT:-true}
FINAL_SNAPSHOT_ID=${FINAL_SNAPSHOT_ID:-db-final-$(date +%Y%m%d-%H%M%S)}
WAIT=${WAIT:-true}

if [[ -z "$DB_ID" ]]; then
  echo "Usage: REGION=ap-southeast-2 $0 <DB_INSTANCE_IDENTIFIER>" >&2
  exit 1
fi

echo "Region: $REGION"
echo "Deleting RDS instance: $DB_ID (skip-final-snapshot=$SKIP_FINAL_SNAPSHOT)"

# Check existence
STATUS=$(aws rds describe-db-instances \
  --region "$REGION" \
  --db-instance-identifier "$DB_ID" \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text 2>/dev/null || echo "None")
if [[ -z "$STATUS" || "$STATUS" == "None" ]]; then
  echo "RDS instance not found: $DB_ID (nothing to do)"
  exit 0
fi
echo "Current status: $STATUS"

if [[ "$SKIP_FINAL_SNAPSHOT" == "true" ]]; then
  aws rds delete-db-instance \
    --region "$REGION" \
    --db-instance-identifier "$DB_ID" \
    --skip-final-snapshot >/dev/null
else
  echo "Creating final snapshot: $FINAL_SNAPSHOT_ID"
  aws rds delete-db-instance \
    --region "$REGION" \
    --db-instance-identifier "$DB_ID" \
    --final-db-snapshot-identifier "$FINAL_SNAPSHOT_ID" >/dev/null
fi

echo "Delete initiated."

if [[ "$WAIT" == "true" ]]; then
  echo "Waiting for deletion to complete..."
  aws rds wait db-instance-deleted --region "$REGION" --db-instance-identifier "$DB_ID"
  echo "RDS instance deleted: $DB_ID"
fi

echo "Done."


