# --- 构建阶段 ---
FROM oven/bun:1.1 AS builder
WORKDIR /app

COPY package.json bun.lockb* ./
RUN bun install

COPY . .
# 运行 Next.js 的生产构建命令
RUN bun run build

# --- 运行阶段 ---
FROM oven/bun:1.1

WORKDIR /app

# 从构建阶段复制构建产物
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules

# 暴露端口
EXPOSE 3000

# 运行 Next.js 的生产服务器
CMD ["bun", "start"]