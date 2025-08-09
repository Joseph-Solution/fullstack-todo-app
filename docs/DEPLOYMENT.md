# 部署说明

## 开发环境

### 启动开发环境
```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 开发环境端口
- 前端: http://localhost:4567
- 后端: http://localhost:5678
- 数据库: localhost:5432

## 生产环境

### 构建生产镜像
```bash
# 构建生产环境镜像
docker-compose -f docker-compose.prod.yml build

# 启动生产环境
docker-compose -f docker-compose.prod.yml up -d

# 查看生产环境日志
docker-compose -f docker-compose.prod.yml logs -f

# 停止生产环境
docker-compose -f docker-compose.prod.yml down
```

### 生产环境端口
- 前端: http://localhost:4567
- 后端: http://localhost:5678
- 数据库: localhost:5432

## 环境变量配置

### 后端环境变量
- `DATABASE_URL`: PostgreSQL 数据库连接字符串
- `PORT`: 服务器端口 (默认: 3001)
- `NODE_ENV`: 环境模式 (development/production)

### 前端环境变量
- `NODE_ENV`: 环境模式 (development/production)

## 数据库迁移

数据库迁移会在容器启动时自动运行。如果需要手动运行迁移：

```bash
# 进入后端容器
docker-compose exec backend bash

# 运行迁移
bun run src/db/migrate.ts
```

## 故障排除

### 检查容器状态
```bash
docker-compose ps
```

### 查看详细日志
```bash
# 查看所有服务日志
docker-compose logs

# 查看特定服务日志
docker-compose logs backend
docker-compose logs frontend
```

### 重新构建镜像
```bash
# 开发环境
docker-compose build

# 生产环境
docker-compose -f docker-compose.prod.yml build
```

### 清理数据
```bash
# 停止并删除所有容器和卷
docker-compose down -v

# 生产环境
docker-compose -f docker-compose.prod.yml down -v
```
