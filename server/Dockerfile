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
# 只复制编译后的代码和 package.json
COPY --from=builder /app/src ./src
COPY --from=builder /app/package.json ./package.json

# 暴露端口
EXPOSE 3001

# 运行生产服务器的命令
CMD ["bun", "src/index.ts"]