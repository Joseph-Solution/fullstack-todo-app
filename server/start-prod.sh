#!/bin/bash

echo "Running database migrations..."
bun run src/db/migrate.ts

echo "Starting production server..."
bun run src/index.ts
