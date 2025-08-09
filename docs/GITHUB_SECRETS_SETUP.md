# GitHub Secrets 配置指南

## 在 GitHub 仓库中配置 Secrets

### 步骤 1: 进入仓库设置
1. 打开你的 GitHub 仓库
2. 点击 `Settings` 标签
3. 在左侧菜单中点击 `Secrets and variables` → `Actions`

### 步骤 2: 添加以下 Secrets

#### 必需的 Secrets

| Secret 名称 | 描述 | 示例值 |
|------------|------|--------|
| `AWS_ACCESS_KEY_ID` | AWS 访问密钥 ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS 秘密访问密钥 | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS 区域 | `us-east-1` |
| `AWS_ACCOUNT_ID` | AWS 账户 ID | `123456789012` |
| `ECR_REPOSITORY` | ECR 仓库名称 | `todo-app` |
| `ECS_CLUSTER_NAME` | ECS 集群名称 | `todo-cluster` |
| `ECS_BACKEND_SERVICE_NAME` | 后端服务名称 | `todo-backend-service` |
| `ECS_FRONTEND_SERVICE_NAME` | 前端服务名称 | `todo-frontend-service` |

#### 可选的 Secrets

| Secret 名称 | 描述 | 示例值 |
|------------|------|--------|
| `ALB_DNS_NAME` | 负载均衡器 DNS 名称 | `todo-alb-123456789.us-east-1.elb.amazonaws.com` |

### 步骤 3: 获取 AWS 凭据

#### 方法 1: 使用现有用户
```bash
# 检查当前用户
aws sts get-caller-identity

# 获取账户 ID
aws sts get-caller-identity --query Account --output text
```

#### 方法 2: 创建新的 IAM 用户 (推荐)
```bash
# 创建用户
aws iam create-user --user-name github-actions

# 创建访问密钥
aws iam create-access-key --user-name github-actions

# 创建策略
aws iam put-user-policy \
  --user-name github-actions \
  --policy-name GitHubActionsPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
  }'
```

### 步骤 4: 验证配置

#### 检查 ECR 仓库
```bash
aws ecr describe-repositories --repository-names todo-app
```

#### 检查 ECS 集群
```bash
aws ecs describe-clusters --clusters todo-cluster
```

#### 检查 ECS 服务
```bash
aws ecs describe-services \
  --cluster todo-cluster \
  --services todo-backend-service todo-frontend-service
```

### 步骤 5: 测试 CI/CD

1. 推送代码到 `release` 分支
```bash
git checkout -b release
git push origin release
```

2. 在 GitHub Actions 中查看部署进度
3. 检查是否有任何错误

### 常见问题

#### 1. 权限错误
```
Error: User: arn:aws:iam::123456789012:user/github-actions is not authorized to perform: ecr:PutImage
```

**解决方案**: 确保 IAM 用户有足够的权限

#### 2. 资源不存在
```
Error: An error occurred (RepositoryNotFoundException) when calling the DescribeRepositories operation
```

**解决方案**: 确保 ECR 仓库已创建

#### 3. 区域不匹配
```
Error: An error occurred (ClusterNotFoundException) when calling the DescribeClusters operation
```

**解决方案**: 确保所有资源都在同一个 AWS 区域

### 安全最佳实践

1. **使用最小权限原则**: 只给 GitHub Actions 用户必要的权限
2. **定期轮换密钥**: 定期更新 AWS 访问密钥
3. **使用环境变量**: 在可能的情况下使用环境变量而不是 secrets
4. **监控访问**: 定期检查 AWS CloudTrail 日志

### 调试技巧

#### 查看 GitHub Actions 日志
1. 进入 Actions 标签
2. 点击失败的 workflow
3. 查看详细的错误信息

#### 本地测试 AWS 命令
```bash
# 测试 ECR 登录
aws ecr get-login-password --region us-east-1

# 测试 ECS 命令
aws ecs describe-clusters --clusters todo-cluster

# 测试 Secrets Manager
aws secretsmanager describe-secret --secret-id todo-database-url
```

### 完整的 Secrets 配置示例

```yaml
# 在 GitHub Secrets 中配置
AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION: us-east-1
AWS_ACCOUNT_ID: 123456789012
ECR_REPOSITORY: todo-app
ECS_CLUSTER_NAME: todo-cluster
ECS_BACKEND_SERVICE_NAME: todo-backend-service
ECS_FRONTEND_SERVICE_NAME: todo-frontend-service
ALB_DNS_NAME: todo-alb-123456789.us-east-1.elb.amazonaws.com
```
