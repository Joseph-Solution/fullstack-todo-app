# 完整重新设置指南

## 为什么需要完全删除？

完全删除之前的服务有以下好处：

1. **避免配置冲突** - 清除所有错误的配置
2. **资源清理** - 释放不必要的资源，节省成本
3. **配置一致性** - 确保所有配置都是最新的
4. **问题排查** - 避免旧配置干扰新部署

## 重新设置步骤

### 步骤 1: 清理现有资源

```bash
# 进入 aws 目录
cd aws

# 给清理脚本执行权限
chmod +x cleanup-aws.sh

# 运行清理脚本
./cleanup-aws.sh
```

### 步骤 2: 重新创建基础设施

```bash
# 给设置脚本执行权限
chmod +x setup-aws.sh

# 运行设置脚本
./setup-aws.sh
```

### 步骤 3: 创建数据库 (如果还没有)

```bash
# 创建 RDS 数据库 (替换为你的实际值)
aws rds create-db-instance \
  --db-instance-identifier todo-database \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username postgres \
  --master-user-password YOUR_STRONG_PASSWORD \
  --allocated-storage 20 \
  --db-name tododb \
  --backup-retention-period 7 \
  --storage-encrypted \
  --region us-east-1
```

### 步骤 4: 创建 Secrets Manager

```bash
# 获取数据库端点
DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier todo-database \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text \
  --region us-east-1)

# 创建数据库连接字符串密钥
aws secretsmanager create-secret \
  --name todo-database-url \
  --description "Database connection string for todo app" \
  --secret-string "postgresql://postgres:YOUR_STRONG_PASSWORD@$DB_ENDPOINT:5432/tododb" \
  --region us-east-1
```

### 步骤 5: 配置 GitHub Secrets

按照 `GITHUB_SECRETS_SETUP.md` 中的指南配置以下 secrets：

```
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=your_account_id
ECR_REPOSITORY=todo-app
ECS_CLUSTER_NAME=todo-cluster
ECS_BACKEND_SERVICE_NAME=todo-backend-service
ECS_FRONTEND_SERVICE_NAME=todo-frontend-service
```

### 步骤 6: 创建 ECS 服务

```bash
# 注册任务定义
aws ecs register-task-definition --cli-input-json file://aws/task-definition-backend.json --region us-east-1
aws ecs register-task-definition --cli-input-json file://aws/task-definition-frontend.json --region us-east-1

# 获取子网和安全组 ID (需要根据你的 VPC 配置)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=todo-vpc" --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=todo-ecs-sg" --query 'SecurityGroups[0].GroupId' --output text)

# 创建后端服务
aws ecs create-service \
  --cluster todo-cluster \
  --service-name todo-backend-service \
  --task-definition todo-backend:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --health-check-grace-period-seconds 60 \
  --region us-east-1

# 创建前端服务
aws ecs create-service \
  --cluster todo-cluster \
  --service-name todo-frontend-service \
  --task-definition todo-frontend:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
  --health-check-grace-period-seconds 60 \
  --region us-east-1
```

### 步骤 7: 测试部署

```bash
# 推送代码到 release 分支
git checkout -b release
git add .
git commit -m "Fresh start with new AWS configuration"
git push origin release
```

### 步骤 8: 验证部署

```bash
# 等待服务稳定
aws ecs wait services-stable \
  --cluster todo-cluster \
  --services todo-backend-service todo-frontend-service \
  --region us-east-1

# 获取任务信息
TASK_ARN=$(aws ecs list-tasks \
  --cluster todo-cluster \
  --service-name todo-backend-service \
  --query 'taskArns[0]' \
  --output text \
  --region us-east-1)

# 获取公共 IP
PUBLIC_IP=$(aws ecs describe-tasks \
  --cluster todo-cluster \
  --tasks $TASK_ARN \
  --query 'tasks[0].attachments[0].details[?name==`publicIp`].value' \
  --output text \
  --region us-east-1)

# 测试健康检查
echo "测试后端健康检查:"
curl -f http://$PUBLIC_IP:3001/health || echo "后端健康检查失败"

echo "测试前端:"
curl -f http://$PUBLIC_IP:3000 || echo "前端检查失败"
```

## 故障排除

### 常见问题

#### 1. 权限错误
```bash
# 检查当前用户权限
aws sts get-caller-identity

# 检查 IAM 策略
aws iam get-user --user-name YOUR_USERNAME
```

#### 2. 网络配置问题
```bash
# 检查 VPC 配置
aws ec2 describe-vpcs --vpc-ids $VPC_ID

# 检查安全组
aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID
```

#### 3. 数据库连接问题
```bash
# 检查 RDS 状态
aws rds describe-db-instances --db-instance-identifier todo-database

# 检查 Secrets Manager
aws secretsmanager describe-secret --secret-id todo-database-url
```

### 调试命令

```bash
# 查看 ECS 服务状态
aws ecs describe-services \
  --cluster todo-cluster \
  --services todo-backend-service todo-frontend-service \
  --region us-east-1

# 查看任务日志
aws logs get-log-events \
  --log-group-name /ecs/todo-backend \
  --log-stream-name ecs/backend/container-id \
  --region us-east-1

# 查看 ECR 镜像
aws ecr list-images \
  --repository-name todo-app \
  --region us-east-1
```

## 成本控制

### 监控成本
```bash
# 查看当前成本
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

### 清理不用的资源
```bash
# 停止服务 (不删除)
aws ecs update-service \
  --cluster todo-cluster \
  --service todo-backend-service \
  --desired-count 0 \
  --region us-east-1

aws ecs update-service \
  --cluster todo-cluster \
  --service todo-frontend-service \
  --desired-count 0 \
  --region us-east-1
```

## 成功标准

✅ **基础设施创建成功**
- ECR 仓库存在
- ECS 集群运行
- RDS 数据库可用
- Secrets Manager 配置正确

✅ **服务部署成功**
- 后端服务运行在端口 3001
- 前端服务运行在端口 3000
- 健康检查通过

✅ **CI/CD 工作正常**
- GitHub Actions 成功执行
- 镜像推送到 ECR
- 服务自动更新

✅ **应用功能正常**
- 可以访问前端页面
- 可以创建/删除 todo 项目
- 数据库连接正常

## 下一步

1. **监控应用** - 设置 CloudWatch 告警
2. **优化性能** - 调整资源配置
3. **安全加固** - 配置 WAF、IAM 策略等
4. **备份策略** - 设置自动备份
5. **扩展性** - 配置自动扩缩容
