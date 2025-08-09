# AWS 部署指南

## 前置要求

### 1. AWS 基础设施
- ECS 集群
- ECR 仓库
- RDS PostgreSQL 数据库
- Application Load Balancer (ALB)
- Secrets Manager (存储数据库连接字符串)
- IAM 角色和策略

### 2. GitHub Secrets 配置
在 GitHub 仓库的 Settings > Secrets and variables > Actions 中配置以下 secrets：

```
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
ECR_REPOSITORY=todo-app
ECS_CLUSTER_NAME=todo-cluster
ECS_BACKEND_SERVICE_NAME=todo-backend-service
ECS_FRONTEND_SERVICE_NAME=todo-frontend-service
ALB_DNS_NAME=your-alb-dns-name
```

## 基础设施设置

### 1. 创建 ECR 仓库
```bash
aws ecr create-repository --repository-name todo-app
```

### 2. 创建 ECS 集群
```bash
aws ecs create-cluster --cluster-name todo-cluster
```

### 3. 创建 IAM 角色

#### ECS Task Execution Role
```bash
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document '{
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
}'

aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

#### ECS Task Role
```bash
aws iam create-role --role-name ecsTaskRole --assume-role-policy-document '{
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
}'
```

### 4. 创建 Secrets Manager
```bash
aws secretsmanager create-secret \
  --name todo-database-url \
  --description "Database connection string for todo app" \
  --secret-string "postgresql://username:password@your-rds-endpoint:5432/tododb"
```

### 5. 创建 CloudWatch Log Groups
```bash
aws logs create-log-group --log-group-name /ecs/todo-backend
aws logs create-log-group --log-group-name /ecs/todo-frontend
```

## 部署流程

### 1. 推送代码到 release 分支
```bash
git checkout -b release
git push origin release
```

### 2. 监控部署
- 在 GitHub Actions 中查看部署进度
- 在 AWS ECS 控制台监控服务状态
- 检查 CloudWatch 日志

### 3. 验证部署
```bash
# 检查后端健康状态
curl http://your-alb-dns-name:5678/health

# 检查前端
curl http://your-alb-dns-name:4567
```

## 故障排除

### 常见问题

#### 1. 镜像构建失败
- 检查 Dockerfile 语法
- 确保所有依赖文件存在
- 查看构建日志

#### 2. ECS 任务启动失败
- 检查任务定义中的镜像 URI
- 验证 IAM 角色权限
- 查看 CloudWatch 日志

#### 3. 数据库连接失败
- 检查 Secrets Manager 中的连接字符串
- 验证 RDS 安全组设置
- 确保 ECS 任务可以访问 RDS

#### 4. 健康检查失败
- 检查容器端口配置
- 验证健康检查命令
- 查看应用日志

### 调试命令

```bash
# 查看 ECS 服务状态
aws ecs describe-services --cluster todo-cluster --services todo-backend-service

# 查看任务日志
aws logs get-log-events --log-group-name /ecs/todo-backend --log-stream-name ecs/backend/container-id

# 查看任务定义
aws ecs describe-task-definition --task-definition todo-backend
```

## 回滚策略

### 自动回滚
如果健康检查失败，ECS 会自动回滚到上一个稳定版本。

### 手动回滚
```bash
# 回滚到特定任务定义版本
aws ecs update-service \
  --cluster todo-cluster \
  --service todo-backend-service \
  --task-definition todo-backend:previous-version
```

## 监控和告警

### CloudWatch 指标
- CPU 和内存使用率
- 请求延迟
- 错误率

### 告警设置
- 服务不可用告警
- 高 CPU/内存使用率告警
- 错误率阈值告警
