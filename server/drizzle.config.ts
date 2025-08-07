import type { Config } from 'drizzle-kit';
import 'dotenv/config'; // 确保环境变量被加载

export default {
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql', // <--- 这里是关键的修改
  dbCredentials: {
    url: process.env.DATABASE_URL!, // <--- 确保这里使用 url
  },
} satisfies Config;