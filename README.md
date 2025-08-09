# 项目文档索引

## 📚 文档分类

### 🎯 项目概况
- **[PROJECT_STATUS_SUMMARY.md](./PROJECT_STATUS_SUMMARY.md)** - 项目状况总结 (必读)
  - 当前状况、已完成工作、发现的问题
  - 需要完成的任务清单
  - 关键配置和故障排除

### 🚀 部署指南
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - 基础部署说明
  - 开发环境和生产环境启动方法
  - 端口配置和环境变量

### ☁️ AWS 配置
- **[AWS_SETUP_CHECKLIST.md](./AWS_SETUP_CHECKLIST.md)** - AWS 基础设施设置清单
  - 详细的 AWS 资源创建步骤
  - 完整的命令行操作指南

- **[AWS_DEPLOYMENT.md](./AWS_DEPLOYMENT.md)** - AWS 部署指南
  - 生产环境部署流程
  - 监控和故障排除

- **[aws/](./aws/)** - AWS 相关脚本和配置
  - `cleanup-aws-actual.sh` - 基于实际配置的清理脚本
  - `setup-aws.sh` - 基础设施设置脚本
  - `detect-resources.sh` - 资源检测脚本
  - `task-definition-backend.json` - 后端任务定义
  - `task-definition-frontend.json` - 前端任务定义

### 🔧 CI/CD 配置
- **[ci-cd/](./ci-cd/)** - CI/CD 相关配置
  - `ci-cd.yml` - GitHub Actions 工作流配置

### 🐳 Docker 配置
- **[docker/](./docker/)** - Docker 相关配置
  - `docker-compose.yml` - 开发环境配置
  - `docker-compose.prod.yml` - 生产环境配置

### 🔐 GitHub Secrets
- **[GITHUB_SECRETS_SETUP.md](./GITHUB_SECRETS_SETUP.md)** - GitHub Secrets 配置指南
  - 必需的 secrets 列表
  - 配置步骤和验证方法

### 🔄 重新设置
- **[FRESH_START_GUIDE.md](./FRESH_START_GUIDE.md)** - 完整重新设置指南
  - 清理现有资源的步骤
  - 重新创建基础设施的流程

## 📋 快速开始

### 新用户必读顺序
1. **[PROJECT_STATUS_SUMMARY.md](./PROJECT_STATUS_SUMMARY.md)** - 了解项目状况
2. **[AWS_SETUP_CHECKLIST.md](./AWS_SETUP_CHECKLIST.md)** - 查看 AWS 设置要求
3. **[GITHUB_SECRETS_SETUP.md](./GITHUB_SECRETS_SETUP.md)** - 配置 GitHub Secrets
4. **[DEPLOYMENT.md](./DEPLOYMENT.md)** - 学习部署方法

### 故障排除
- 查看 **[PROJECT_STATUS_SUMMARY.md](./PROJECT_STATUS_SUMMARY.md)** 中的故障排除部分
- 使用 `aws/detect-resources.sh` 检测当前资源状态
- 参考 **[AWS_DEPLOYMENT.md](./AWS_DEPLOYMENT.md)** 中的调试命令

## 🔄 文档更新

- **最后更新**: 2024年12月
- **状态**: 需要重新配置 AWS 基础设施
- **下一步**: 清理现有资源并重新创建分离的服务架构

## 📞 支持

如果遇到问题，请：
1. 查看相关文档
2. 运行检测脚本确认资源状态
3. 检查错误日志
4. 参考故障排除指南
