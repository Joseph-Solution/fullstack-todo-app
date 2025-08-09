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