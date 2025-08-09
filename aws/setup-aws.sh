#!/bin/bash

# AWS 快速设置脚本
# 使用方法: ./setup-aws.sh

set -e

echo "🚀 开始 AWS 基础设施设置..."

# 配置变量 (请根据你的环境修改)
REGION="ap-southeast-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
VPC_ID=""
SUBNET_IDS=""
SECURITY_GROUP_ID=""

echo "📍 区域: $REGION"
echo "🆔 账户 ID: $ACCOUNT_ID"

# 1. 创建 ECR 仓库
echo "📦 创建 ECR 仓库..."
aws ecr create-repository --repository-name joseph-solution/fullstack-todo-app --region $REGION || echo "仓库已存在"

# 2. 创建 CloudWatch 日志组
echo "📝 创建 CloudWatch 日志组..."
aws logs create-log-group --log-group-name /ecs/todo-backend --region $REGION || echo "后端日志组已存在"
aws logs create-log-group --log-group-name /ecs/todo-frontend --region $REGION || echo "前端日志组已存在"

# 3. 创建 IAM 角色
echo "🔐 创建 IAM 角色..."

# ECS Task Execution Role
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }' || echo "ECS Task Execution Role 已存在"

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy || echo "策略已附加"

# ECS Task Role
aws iam create-role \
  --role-name ecsTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }' || echo "ECS Task Role 已存在"

# 4. 创建 ECS 集群
echo "🐳 创建 ECS 集群..."
aws ecs create-cluster \
  --cluster-name todo-app-cluster \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
  --region $REGION || echo "集群已存在"

# 5. 更新任务定义文件中的占位符
echo "📋 更新任务定义文件..."

# 更新后端任务定义
sed -i "s|ACCOUNT_ID|$ACCOUNT_ID|g" aws/task-definition-backend.json
sed -i "s|REGION|$REGION|g" aws/task-definition-backend.json
sed -i "s|REPOSITORY_NAME|joseph-solution/fullstack-todo-app|g" aws/task-definition-backend.json

# 更新前端任务定义
sed -i "s|ACCOUNT_ID|$ACCOUNT_ID|g" aws/task-definition-frontend.json
sed -i "s|REGION|$REGION|g" aws/task-definition-frontend.json
sed -i "s|REPOSITORY_NAME|joseph-solution/fullstack-todo-app|g" aws/task-definition-frontend.json

echo "✅ AWS 基础设施设置完成！"
echo ""
echo "📋 下一步需要手动配置:"
echo "1. 创建 RDS PostgreSQL 数据库"
echo "2. 创建 VPC 和安全组 (如果还没有)"
echo "3. 在 Secrets Manager 中存储数据库连接字符串"
echo "4. 在 GitHub Secrets 中配置必要的密钥"
echo "5. 运行 ECS 服务创建命令"
echo ""
echo "🔗 查看详细设置指南: AWS_SETUP_CHECKLIST.md"
