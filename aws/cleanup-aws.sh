#!/bin/bash

# AWS 资源清理脚本
# 使用方法: ./cleanup-aws.sh

set -e

echo "🧹 开始清理 AWS 资源..."

# 配置变量
REGION="us-east-1"
CLUSTER_NAME="todo-cluster"
BACKEND_SERVICE="todo-backend-service"
FRONTEND_SERVICE="todo-frontend-service"
ECR_REPOSITORY="todo-app"
SECRET_NAME="todo-database-url"

echo "📍 区域: $REGION"

# 1. 删除 ECS 服务
echo "🐳 删除 ECS 服务..."

# 检查并删除后端服务
if aws ecs describe-services --cluster $CLUSTER_NAME --services $BACKEND_SERVICE --region $REGION --query 'services[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    echo "  删除后端服务: $BACKEND_SERVICE"
    aws ecs update-service --cluster $CLUSTER_NAME --service $BACKEND_SERVICE --desired-count 0 --region $REGION
    aws ecs wait services-stable --cluster $CLUSTER_NAME --services $BACKEND_SERVICE --region $REGION
    aws ecs delete-service --cluster $CLUSTER_NAME --service $BACKEND_SERVICE --region $REGION
else
    echo "  后端服务不存在或已删除"
fi

# 检查并删除前端服务
if aws ecs describe-services --cluster $CLUSTER_NAME --services $FRONTEND_SERVICE --region $REGION --query 'services[0].status' --output text 2>/dev/null | grep -q "ACTIVE"; then
    echo "  删除前端服务: $FRONTEND_SERVICE"
    aws ecs update-service --cluster $CLUSTER_NAME --service $FRONTEND_SERVICE --desired-count 0 --region $REGION
    aws ecs wait services-stable --cluster $CLUSTER_NAME --services $FRONTEND_SERVICE --region $REGION
    aws ecs delete-service --cluster $CLUSTER_NAME --service $FRONTEND_SERVICE --region $REGION
else
    echo "  前端服务不存在或已删除"
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
# 删除后端任务定义的所有版本
for revision in $(aws ecs list-task-definitions --family-prefix todo-backend --region $REGION --query 'taskDefinitionArns[]' --output text 2>/dev/null); do
    echo "  删除任务定义: $revision"
    aws ecs deregister-task-definition --task-definition $revision --region $REGION
done

# 删除前端任务定义的所有版本
for revision in $(aws ecs list-task-definitions --family-prefix todo-frontend --region $REGION --query 'taskDefinitionArns[]' --output text 2>/dev/null); do
    echo "  删除任务定义: $revision"
    aws ecs deregister-task-definition --task-definition $revision --region $REGION
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

# 5. 删除 Secrets Manager 密钥
echo "🔐 删除 Secrets Manager 密钥..."
if aws secretsmanager describe-secret --secret-id $SECRET_NAME --region $REGION >/dev/null 2>&1; then
    echo "  删除密钥: $SECRET_NAME"
    aws secretsmanager delete-secret --secret-id $SECRET_NAME --force-delete-without-recovery --region $REGION
else
    echo "  密钥不存在"
fi

# 6. 删除 CloudWatch 日志组
echo "📝 删除 CloudWatch 日志组..."
if aws logs describe-log-groups --log-group-name-prefix "/ecs/todo-backend" --region $REGION --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "/ecs/todo-backend"; then
    echo "  删除后端日志组: /ecs/todo-backend"
    aws logs delete-log-group --log-group-name /ecs/todo-backend --region $REGION
else
    echo "  后端日志组不存在"
fi

if aws logs describe-log-groups --log-group-name-prefix "/ecs/todo-frontend" --region $REGION --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "/ecs/todo-frontend"; then
    echo "  删除前端日志组: /ecs/todo-frontend"
    aws logs delete-log-group --log-group-name /ecs/todo-frontend --region $REGION
else
    echo "  前端日志组不存在"
fi

# 7. 删除 IAM 角色 (可选，因为可能被其他服务使用)
echo "🔑 检查 IAM 角色..."
echo "  注意: IAM 角色不会被自动删除，因为它们可能被其他服务使用"
echo "  如果需要删除，请手动执行以下命令:"
echo "    aws iam delete-role --role-name ecsTaskExecutionRole"
echo "    aws iam delete-role --role-name ecsTaskRole"

# 8. 检查是否有其他相关资源
echo "🔍 检查其他相关资源..."

# 检查负载均衡器
ALB_ARN=$(aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[?contains(LoadBalancerName, `todo`)].LoadBalancerArn' --output text 2>/dev/null)
if [ ! -z "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    echo "  发现负载均衡器: $ALB_ARN"
    echo "  请手动删除负载均衡器:"
    echo "    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region $REGION"
fi

# 检查目标组
TARGET_GROUPS=$(aws elbv2 describe-target-groups --region $REGION --query 'TargetGroups[?contains(TargetGroupName, `todo`)].TargetGroupArn' --output text 2>/dev/null)
if [ ! -z "$TARGET_GROUPS" ] && [ "$TARGET_GROUPS" != "None" ]; then
    echo "  发现目标组: $TARGET_GROUPS"
    echo "  请手动删除目标组:"
    for tg in $TARGET_GROUPS; do
        echo "    aws elbv2 delete-target-group --target-group-arn $tg --region $REGION"
    done
fi

echo "✅ AWS 资源清理完成！"
echo ""
echo "📋 下一步:"
echo "1. 运行 setup-aws.sh 重新创建基础设施"
echo "2. 配置 GitHub Secrets"
echo "3. 推送代码到 release 分支进行测试"
echo ""
echo "⚠️  注意: 如果使用了 RDS 数据库，请手动决定是否删除:"
echo "   aws rds delete-db-instance --db-instance-identifier todo-database --skip-final-snapshot"
