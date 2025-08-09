#!/bin/bash

# AWS 资源检测脚本
# 使用方法: ./detect-resources.sh

set -e

echo "🔍 检测现有的 AWS 资源..."

# 获取当前区域
CURRENT_REGION=$(aws configure get region || echo "us-east-1")
echo "🌍 当前区域: $CURRENT_REGION"

# 获取账户 ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "🆔 账户 ID: $ACCOUNT_ID"

echo ""
echo "=== ECS 资源检测 ==="

# 检测 ECS 集群
echo "🐳 检测 ECS 集群..."
CLUSTERS=$(aws ecs list-clusters --region $CURRENT_REGION --query 'clusterArns[]' --output text 2>/dev/null || echo "")

if [ ! -z "$CLUSTERS" ]; then
    echo "发现以下集群:"
    for cluster in $CLUSTERS; do
        CLUSTER_NAME=$(echo $cluster | cut -d'/' -f2)
        echo "  - $CLUSTER_NAME ($cluster)"
    done
else
    echo "  没有找到 ECS 集群"
fi

# 检测 ECS 服务
echo ""
echo "🐳 检测 ECS 服务..."
if [ ! -z "$CLUSTERS" ]; then
    for cluster in $CLUSTERS; do
        CLUSTER_NAME=$(echo $cluster | cut -d'/' -f2)
        echo "  集群 $CLUSTER_NAME 中的服务:"
        
        SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME --region $CURRENT_REGION --query 'serviceArns[]' --output text 2>/dev/null || echo "")
        
        if [ ! -z "$SERVICES" ]; then
            for service in $SERVICES; do
                SERVICE_NAME=$(echo $service | cut -d'/' -f3)
                echo "    - $SERVICE_NAME ($service)"
            done
        else
            echo "    没有找到服务"
        fi
    done
fi

# 检测 ECR 仓库
echo ""
echo "=== ECR 资源检测 ==="
echo "📦 检测 ECR 仓库..."
REPOSITORIES=$(aws ecr describe-repositories --region $CURRENT_REGION --query 'repositories[].repositoryName' --output text 2>/dev/null || echo "")

if [ ! -z "$REPOSITORIES" ]; then
    echo "发现以下 ECR 仓库:"
    for repo in $REPOSITORIES; do
        echo "  - $repo"
    done
else
    echo "  没有找到 ECR 仓库"
fi

echo ""
echo "=== ALB detection ==="
echo "🔧 Listing Application Load Balancers..."
LB_NAMES=$(aws elbv2 describe-load-balancers --region $CURRENT_REGION --query 'LoadBalancers[].LoadBalancerName' --output text 2>/dev/null || echo "")
if [ ! -z "$LB_NAMES" ]; then
    echo "Found ALBs:"
    for name in $LB_NAMES; do
        ARN=$(aws elbv2 describe-load-balancers --region $CURRENT_REGION --names $name --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
        STATE=$(aws elbv2 describe-load-balancers --region $CURRENT_REGION --names $name --query 'LoadBalancers[0].State.Code' --output text 2>/dev/null || echo "")
        echo "  - $name (state: $STATE, arn: $ARN)"
    done
else
    echo "  No ALBs found"
fi

echo ""
echo "=== Target groups detection ==="
echo "🎯 Listing target groups (showing name and arn)..."
TGS=$(aws elbv2 describe-target-groups --region $CURRENT_REGION --query 'TargetGroups[].{Name:TargetGroupName,Arn:TargetGroupArn}' --output text 2>/dev/null || echo "")
if [ ! -z "$TGS" ]; then
    echo "$TGS" | while read -r Name Arn; do
        [ -z "$Name" ] && continue
        echo "  - $Name ($Arn)"
    done
else
    echo "  No target groups found"
fi

echo ""
echo "=== Security groups (default VPC) ==="
echo "🔒 Listing SGs in default VPC (id and name)..."
DEFAULT_VPC=$(aws ec2 describe-vpcs --region $CURRENT_REGION --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" = "None" ]; then
    echo "  No default VPC detected"
else
    SGS=$(aws ec2 describe-security-groups --region $CURRENT_REGION --filters Name=vpc-id,Values=$DEFAULT_VPC --query 'SecurityGroups[].{Id:GroupId,Name:GroupName}' --output text 2>/dev/null || echo "")
    if [ ! -z "$SGS" ]; then
        echo "$SGS" | while read -r Id Name; do
            [ -z "$Id" ] && continue
            echo "  - $Name ($Id)"
        done
    else
        echo "  No security groups found"
    fi
fi

echo ""
echo "=== RDS 检测 ==="
echo "🗄️  列出 RDS PostgreSQL/其他实例..."
DB_IDS=$(aws rds describe-db-instances --region $CURRENT_REGION --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null || echo "")
if [ ! -z "$DB_IDS" ]; then
    for dbid in $DB_IDS; do
        STATUS=$(aws rds describe-db-instances --region $CURRENT_REGION --db-instance-identifier $dbid --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "")
        ENGINE=$(aws rds describe-db-instances --region $CURRENT_REGION --db-instance-identifier $dbid --query 'DBInstances[0].Engine' --output text 2>/dev/null || echo "")
        EP=$(aws rds describe-db-instances --region $CURRENT_REGION --db-instance-identifier $dbid --query 'DBInstances[0].Endpoint.Address' --output text 2>/dev/null || echo "")
        PORT=$(aws rds describe-db-instances --region $CURRENT_REGION --db-instance-identifier $dbid --query 'DBInstances[0].Endpoint.Port' --output text 2>/dev/null || echo "")
        echo "  - $dbid (status: $STATUS, engine: $ENGINE, endpoint: $EP:$PORT)"
    done
else
    echo "  没有找到 RDS 实例"
fi

echo ""
echo "=== IAM 角色检测 ==="
echo "🧩 关键角色 (ecsTaskExecutionRole / ecsTaskRole) ..."
for r in ecsTaskExecutionRole ecsTaskRole; do
    ROLE_ARN=$(aws iam get-role --role-name $r --query 'Role.Arn' --output text 2>/dev/null || echo "None")
    if [ "$ROLE_ARN" != "None" ]; then
        echo "  - $r ($ROLE_ARN)"
    else
        echo "  - $r 未找到"
    fi
done

echo "🔎 匹配名称包含: ecsTask / todo / app / oidc / github 的角色..."
MATCHED=$(aws iam list-roles --query 'Roles[?contains(RoleName, `ecsTask`) || contains(RoleName, `todo`) || contains(RoleName, `app`) || contains(RoleName, `oidc`) || contains(RoleName, `github`)].RoleName' --output text 2>/dev/null || echo "")
if [ ! -z "$MATCHED" ]; then
    for name in $MATCHED; do
        echo "  - $name"
    done
else
    echo "  没有匹配到相关角色"
fi