import { serial, text, boolean, pgTable } from 'drizzle-orm/pg-core';

// 定义一个名为 'todos' 的表
export const todos = pgTable('todos', {
  id: serial('id').primaryKey(), // 自增主键 ID
  text: text('text').notNull(),    // 任务内容，不能为空
  completed: boolean('completed').default(false), // 完成状态，默认为 false
});