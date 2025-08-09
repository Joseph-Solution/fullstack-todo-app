# AWS 基础设施设置完整清单

## 1. ECR (Elastic Container Registry) - 容器镜像仓库

### 创建 ECR 仓库
```bash
# 创建主仓库
aws ecr create-repository --repository-name todo-app

# 验证仓库创建
aws ecr describe-repositories --repository-names todo-app
```

### 获取 ECR 登录命令
```bash
# 获取登录命令
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

---

## 2. RDS (Relational Database Service) - 数据库

### 创建 PostgreSQL 数据库
```bash
# 创建数据库子网组
aws rds create-db-subnet-group \
  --db-subnet-group-name todo-db-subnet-group \
  --db-subnet-group-description "Subnet group for todo app database" \
  --subnet-ids subnet-12345678 subnet-87654321

# 创建数据库实例
aws rds create-db-instance \
  --db-instance-identifier todo-database \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username postgres \
  --master-user-password YOUR_PASSWORD \
  --allocated-storage 20 \
  --db-subnet-group-name todo-db-subnet-group \
  --vpc-security-group-ids sg-12345678 \
  --backup-retention-period 7 \
  --storage-encrypted \
  --deletion-protection
```

### 获取数据库连接信息
```bash
# 获取数据库端点
aws rds describe-db-instances --db-instance-identifier todo-database --query 'DBInstances[0].Endpoint.Address' --output text

# 获取数据库端口
aws rds describe-db-instances --db-instance-identifier todo-database --query 'DBInstances[0].Endpoint.Port' --output text
```

---

## 3. VPC 和网络配置

### 创建 VPC (如果还没有)
```bash
# 创建 VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=todo-vpc}]'

# 创建子网
aws ec2 create-subnet --vpc-id vpc-12345678 --cidr-block 10.0.1.0/24 --availability-zone us-east-1a
aws ec2 create-subnet --vpc-id vpc-12345678 --cidr-block 10.0.2.0/24 --availability-zone us-east-1b

# 创建互联网网关
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --vpc-id vpc-12345678 --internet-gateway-id igw-12345678

# 创建路由表
aws ec2 create-route-table --vpc-id vpc-12345678
aws ec2 create-route --route-table-id rtb-12345678 --destination-cidr-block 0.0.0.0/0 --gateway-id igw-12345678
```

### 安全组配置
```bash
# 创建 ECS 安全组
aws ec2 create-security-group \
  --group-name todo-ecs-sg \
  --description "Security group for ECS tasks" \
  --vpc-id vpc-12345678

# 允许内部通信
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 3001 \
  --source-group sg-12345678

aws ec2 authorize-security-group-ingress \
  --group-id sg-12345678 \
  --protocol tcp \
  --port 3000 \
  --source-group sg-12345678

# 创建 RDS 安全组
aws ec2 create-security-group \
  --group-name todo-rds-sg \
  --description "Security group for RDS database" \
  --vpc-id vpc-12345678

# 允许 ECS 访问 RDS
aws ec2 authorize-security-group-ingress \
  --group-id sg-87654321 \
  --protocol tcp \
  --port 5432 \
  --source-group sg-12345678
```

---

## 4. IAM 角色和策略

### 创建 ECS Task Execution Role
```bash
# 创建角色
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
  }'

# 附加托管策略
aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# 创建自定义策略用于访问 Secrets Manager
aws iam put-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-name SecretsManagerAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Resource": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:todo-database-url*"
      }
    ]
  }'
```

### 创建 ECS Task Role
```bash
# 创建角色
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
  }'

# 创建策略（如果需要额外的权限）
aws iam put-role-policy \
  --role-name ecsTaskRole \
  --policy-name TaskPermissions \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
  }'
```

---

## 5. Secrets Manager - 存储敏感信息

### 创建数据库连接字符串密钥
```bash
# 创建密钥
aws secretsmanager create-secret \
  --name todo-database-url \
  --description "Database connection string for todo app" \
  --secret-string "postgresql://postgres:YOUR_PASSWORD@YOUR_RDS_ENDPOINT:5432/tododb"

# 验证密钥创建
aws secretsmanager describe-secret --secret-id todo-database-url
```

---

## 6. CloudWatch Logs - 日志管理

### 创建日志组
```bash
# 创建后端日志组
aws logs create-log-group --log-group-name /ecs/todo-backend

# 创建前端日志组
aws logs create-log-group --log-group-name /ecs/todo-frontend

# 设置日志保留策略
aws logs put-retention-policy --log-group-name /ecs/todo-backend --retention-in-days 30
aws logs put-retention-policy --log-group-name /ecs/todo-frontend --retention-in-days 30
```

---

## 7. ECS (Elastic Container Service) - 容器编排

### 创建 ECS 集群
```bash
# 创建集群
aws ecs create-cluster \
  --cluster-name todo-cluster \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1

# 验证集群创建
aws ecs describe-clusters --clusters todo-cluster
```

### 创建 ECS 服务

#### 后端服务
```bash
# 注册任务定义
aws ecs register-task-definition --cli-input-json file://aws/task-definition-backend.json

# 创建服务
aws ecs create-service \
  --cluster todo-cluster \
  --service-name todo-backend-service \
  --task-definition todo-backend:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678,subnet-87654321],securityGroups=[sg-12345678],assignPublicIp=ENABLED}" \
  --health-check-grace-period-seconds 60
```

#### 前端服务
```bash
# 注册任务定义
aws ecs register-task-definition --cli-input-json file://aws/task-definition-frontend.json

# 创建服务
aws ecs create-service \
  --cluster todo-cluster \
  --service-name todo-frontend-service \
  --task-definition todo-frontend:1 \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678,subnet-87654321],securityGroups=[sg-12345678],assignPublicIp=ENABLED}" \
  --health-check-grace-period-seconds 60
```

---

## 8. Application Load Balancer (可选)

### 创建 ALB
```bash
# 创建负载均衡器
aws elbv2 create-load-balancer \
  --name todo-alb \
  --subnets subnet-12345678 subnet-87654321 \
  --security-groups sg-12345678

# 创建目标组
aws elbv2 create-target-group \
  --name todo-backend-tg \
  --protocol HTTP \
  --port 3001 \
  --vpc-id vpc-12345678 \
  --target-type ip \
  --health-check-path /health

aws elbv2 create-target-group \
  --name todo-frontend-tg \
  --protocol HTTP \
  --port 3000 \
  --vpc-id vpc-12345678 \
  --target-type ip \
  --health-check-path /
```

---

## 9. 验证设置

### 检查所有资源
```bash
# 检查 ECS 集群
aws ecs describe-clusters --clusters todo-cluster

# 检查 ECS 服务
aws ecs describe-services --cluster todo-cluster --services todo-backend-service todo-frontend-service

# 检查 RDS 实例
aws rds describe-db-instances --db-instance-identifier todo-database

# 检查 ECR 仓库
aws ecr describe-repositories --repository-names todo-app

# 检查 Secrets Manager
aws secretsmanager describe-secret --secret-id todo-database-url
```

### 测试连接
```bash
# 获取服务公共 IP
aws ecs describe-tasks --cluster todo-cluster --tasks $(aws ecs list-tasks --cluster todo-cluster --service-name todo-backend-service --query 'taskArns[]' --output text)

# 测试后端健康检查
curl http://TASK_PUBLIC_IP:3001/health

# 测试前端
curl http://TASK_PUBLIC_IP:3000
```

---

## 10. 清理旧资源 (如果需要重新开始)

### 删除现有资源
```bash
# 删除 ECS 服务
aws ecs update-service --cluster todo-cluster --service todo-backend-service --desired-count 0
aws ecs delete-service --cluster todo-cluster --service todo-backend-service
aws ecs update-service --cluster todo-cluster --service todo-frontend-service --desired-count 0
aws ecs delete-service --cluster todo-cluster --service todo-frontend-service

# 删除 ECS 集群
aws ecs delete-cluster --cluster todo-cluster

# 删除 RDS 实例
aws rds delete-db-instance --db-instance-identifier todo-database --skip-final-snapshot

# 删除 ECR 仓库
aws ecr delete-repository --repository-name todo-app --force

# 删除 Secrets Manager
aws secretsmanager delete-secret --secret-id todo-database-url --force-delete-without-recovery

# 删除 CloudWatch 日志组
aws logs delete-log-group --log-group-name /ecs/todo-backend
aws logs delete-log-group --log-group-name /ecs/todo-frontend
```

---

## 重要提醒

1. **替换占位符**: 将所有的 `ACCOUNT_ID`, `YOUR_PASSWORD`, `YOUR_RDS_ENDPOINT` 等替换为实际值
2. **区域一致性**: 确保所有资源都在同一个 AWS 区域
3. **权限检查**: 确保你的 AWS 用户有足够的权限创建这些资源
4. **成本控制**: 使用完毕后记得清理不需要的资源以避免额外费用
5. **安全最佳实践**: 
   - 使用强密码
   - 限制安全组访问
   - 启用加密
   - 定期轮换密钥
