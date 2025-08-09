#!/bin/bash

# AWS 资源清理脚本 - 基于实际检测结果
# 使用方法: ./cleanup-aws-actual.sh

set -e

echo "🔍 开始清理 AWS 资源..."

# 根据检测结果配置变量
REGION="ap-southeast-2"
CLUSTER_NAME="todo-app-cluster"
SERVICE_NAME="todo-app-service"  # 你只有一个服务
ECR_REPOSITORY="joseph-solution/fullstack-todo-app"
ACCOUNT_ID="248729599833"

echo "📍 区域: $REGION"
echo "🆔 账户 ID: $ACCOUNT_ID"

# 1. 删除 ECS 服务
echo "🐳 删除 ECS 服务..."

# 检查并删除服务
if aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION --query 'services[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    echo "  删除服务: $SERVICE_NAME"
    aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 0 --region $REGION
    aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION
    aws ecs delete-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --region $REGION
else
    echo "  服务不存在或已删除"
fi

# 2. 删除 ECS 集群
echo "🐳 删除 ECS 集群..."
if aws ecs describe-clusters --clusters $CLUSTER_NAME --region $REGION --query 'clusters[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    echo "  删除集群: $CLUSTER_NAME"
    aws ecs delete-cluster --cluster $CLUSTER_NAME --region $REGION
else
    echo "  集群不存在或已删除"
fi

# 3. 删除任务定义
echo "📋 删除任务定义..."
# 删除所有相关的任务定义
for revision in $(aws ecs list-task-definitions --region $REGION --query 'taskDefinitionArns[]' --output text 2>/dev/null); do
    TASK_FAMILY=$(echo $revision | cut -d'/' -f2)
    if [[ $TASK_FAMILY == *"todo"* ]] || [[ $TASK_FAMILY == *"app"* ]]; then
        echo "  删除任务定义: $revision"
        aws ecs deregister-task-definition --task-definition $revision --region $REGION
    fi
done

# 4. 删除 ECR 仓库中的镜像
echo "📦 清理 ECR 仓库..."
if aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $REGION >/dev/null 2>&1; then
    echo "  删除 ECR 仓库中的所有镜像..."
    
    # 获取所有镜像标签
    IMAGE_TAGS=$(aws ecr list-images --repository-name $ECR_REPOSITORY --region $REGION --query 'imageIds[].imageTag' --output text 2>/dev/null)
    
    if [ ! -z "$IMAGE_TAGS" ]; then
        # 构建删除命令
        DELETE_COMMAND="aws ecr batch-delete-image --repository-name $ECR_REPOSITORY --image-ids"
        for tag in $IMAGE_TAGS; do
            DELETE_COMMAND="$DELETE_COMMAND imageTag=$tag"
        done
        eval "$DELETE_COMMAND --region $REGION"
        echo "  已删除镜像标签: $IMAGE_TAGS"
    else
        echo "  没有找到镜像"
    fi
    
    # 删除仓库
    echo "  删除 ECR 仓库: $ECR_REPOSITORY"
    aws ecr delete-repository --repository-name $ECR_REPOSITORY --force --region $REGION
else
    echo "  ECR 仓库不存在"
fi

# 5. 删除相关的 Secrets Manager 密钥
echo "🔒 删除 Secrets Manager 密钥..."
SECRETS=$(aws secretsmanager list-secrets --region $REGION --query 'SecretList[?contains(Name, `todo`) || contains(Name, `app`) || contains(Name, `database`)].Name' --output text 2>/dev/null || echo "")

if [ ! -z "$SECRETS" ]; then
    for secret in $SECRETS; do
        echo "  删除密钥: $secret"
        aws secretsmanager delete-secret --secret-id $secret --force-delete-without-recovery --region $REGION
    done
else
    echo "  没有找到相关的密钥"
fi

# 6. 删除相关的 CloudWatch 日志组
echo "📝 删除 CloudWatch 日志组..."
LOG_GROUPS=$(aws logs describe-log-groups --region $REGION --query 'logGroups[?contains(logGroupName, `todo`) || contains(logGroupName, `app`) || contains(logGroupName, `ecs`)].logGroupName' --output text 2>/dev/null || echo "")

if [ ! -z "$LOG_GROUPS" ]; then
    for loggroup in $LOG_GROUPS; do
        echo "  删除日志组: $loggroup"
        aws logs delete-log-group --log-group-name $loggroup --region $REGION
    done
else
    echo "  没有找到相关的日志组"
fi

echo "✅ AWS 资源清理完成！"
echo ""
echo "📋 下一步:"
echo "1. 运行 setup-aws.sh 重新创建基础设施"
echo "2. 配置 GitHub Secrets (注意区域改为 ap-southeast-2)"
echo "3. 推送代码到 release 分支进行测试"