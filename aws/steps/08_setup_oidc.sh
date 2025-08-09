#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo ".env not found at $ENV_FILE" >&2; exit 1; }

# Load env values we need
get_env() { grep -E "^$1=" "$ENV_FILE" | head -n1 | cut -d'=' -f2-; }
AWS_REGION=${AWS_REGION:-$(get_env AWS_REGION)}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(get_env AWS_ACCOUNT_ID)}
REPO_SLUG=${REPO:-$(get_env REPO)}
REPO_SLUG=${REPO_SLUG:-""}
[ -n "$REPO_SLUG" ] || { echo "REPO (owner/repo) not set in .env" >&2; exit 1; }
GH_OWNER=${GH_OWNER:-${REPO_SLUG%%/*}}
GH_REPO=${GH_REPO:-${REPO_SLUG##*/}}
GH_REF=${GH_REF:-refs/heads/release}
ROLE_NAME=${ROLE_NAME:-GitHubActionsDeployer}

# helper: upsert key=value into .env
upsert() {
  local key="$1" val="$2" file="$3"
  if [ -f "$file" ] && grep -q "^${key}=" "$file"; then
    sed -i "s#^${key}=.*#${key}=${val}#" "$file"
  else
    echo "${key}=${val}" >> "$file"
  fi
}

echo "Using: REGION=$AWS_REGION ACCOUNT_ID=$AWS_ACCOUNT_ID REPO=$REPO_SLUG ROLE=$ROLE_NAME"

# 1) Ensure OIDC provider exists
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  echo "Creating OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
    --region "$AWS_REGION" >/dev/null
else
  echo "OIDC provider exists: $OIDC_ARN"
fi

# 2) Create/Update IAM role with trust policy
TRUST_JSON=$(mktemp)
cat > "$TRUST_JSON" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${OIDC_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
      "StringLike": { "token.actions.githubusercontent.com:sub": "repo:${GH_OWNER}/${GH_REPO}:ref:${GH_REF}" }
    }
  }]
}
EOF

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  echo "Creating role $ROLE_NAME ..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://"$TRUST_JSON" \
    --region "$AWS_REGION" >/dev/null
else
  echo "Updating trust policy for $ROLE_NAME ..."
  aws iam update-assume-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-document file://"$TRUST_JSON" >/dev/null
fi

# 3) Attach inline minimal policy (ECR push, ECS deploy, PassRole)
POLICY_JSON=$(mktemp)
cat > "$POLICY_JSON" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "EcrLoginAndPush", "Effect": "Allow", "Action": [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeRepositories",
      "ecr:BatchGetImage"
    ], "Resource": "*" },
    { "Sid": "EcsDeploy", "Effect": "Allow", "Action": [
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeClusters",
      "ecs:ListTaskDefinitions"
    ], "Resource": "*" },
    { "Sid": "PassTaskRoles", "Effect": "Allow", "Action": "iam:PassRole", "Resource": [
      "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
      "arn:aws:iam::ACCOUNT_ID:role/ecsTaskRole"
    ]}
  ]
}
EOF
sed -i "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" "$POLICY_JSON"
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name GitHubActionsEcsDeploy \
  --policy-document file://"$POLICY_JSON" \
  --region "$AWS_REGION" >/dev/null

echo "Role ready: $ROLE_ARN"
upsert GHA_OIDC_ROLE_ARN "$ROLE_ARN" "$ENV_FILE"
echo "Updated $ENV_FILE with GHA_OIDC_ROLE_ARN"
