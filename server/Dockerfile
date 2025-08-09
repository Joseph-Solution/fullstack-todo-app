# --- 构建阶段 ---
FROM oven/bun:1.1 AS builder
WORKDIR /app

# 只复制 package.json 和 lockfile 来安装依赖
COPY package.json bun.lockb* ./
RUN bun install --production

# 复制所有源代码
COPY . .

# --- 运行阶段 ---
FROM oven/bun:1.1

WORKDIR /app

# 从构建阶段复制安装好的依赖
COPY --from=builder /app/node_modules ./node_modules
# 复制源代码和配置文件
COPY --from=builder /app/src ./src
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/drizzle ./drizzle
COPY --from=builder /app/drizzle.config.ts ./drizzle.config.ts

# 创建启动脚本
COPY start-prod.sh ./
RUN chmod +x start-prod.sh

# 暴露端口（与本地一致）
EXPOSE 5678

# 运行生产服务器的命令
ENTRYPOINT []
CMD ["/bin/sh", "./start-prod.sh"]