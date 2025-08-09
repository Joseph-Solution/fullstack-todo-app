#!/bin/sh

PORT="${PORT:-4567}"
HOST="0.0.0.0"
echo "Starting Next.js development server on port $PORT..."
HOST="$HOST" bun run dev -- -p "$PORT" -H "$HOST"
