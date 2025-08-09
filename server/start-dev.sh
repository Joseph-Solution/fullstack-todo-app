#!/bin/sh

echo "Waiting for database to be ready..."
# 等待数据库连接
while ! bun run src/db/migrate.ts; do
  echo "Database is unavailable - sleeping"
  sleep 2
done

echo "Database is ready! Starting server..."
bun run src/index.ts
