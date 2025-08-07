import express from 'express';
import cors from 'cors';
import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import 'dotenv/config';
import { todos } from './db/schema';
import { eq } from 'drizzle-orm';

// --- 数据库连接 ---
if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is not set');
}
const connectionString = process.env.DATABASE_URL;
const client = postgres(connectionString);
const db = drizzle(client);

// --- Express 应用设置 ---
const app = express();
app.use(cors()); // 允许跨域请求
app.use(express.json()); // 解析 JSON 请求体

const PORT = process.env.PORT || 3001;

// --- API 路由 ---

// GET /api/todos - 获取所有任务
app.get('/api/todos', async (req, res) => {
  try {
    const allTodos = await db.select().from(todos).orderBy(todos.id);
    res.json(allTodos);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch todos' });
  }
});

// POST /api/todos - 创建一个新任务
app.post('/api/todos', async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) {
      return res.status(400).json({ error: 'Text is required' });
    }
    const [newTodo] = await db.insert(todos).values({ text }).returning();
    res.status(201).json(newTodo);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to create todo' });
  }
});

// PUT /api/todos/:id - 更新任务（切换完成状态）
app.put('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { completed } = req.body;

    const [updatedTodo] = await db
      .update(todos)
      .set({ completed })
      .where(eq(todos.id, parseInt(id, 10)))
      .returning();

    if (updatedTodo) {
      res.json(updatedTodo);
    } else {
      res.status(404).json({ error: 'Todo not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update todo' });
  }
});

// DELETE /api/todos/:id - 删除一个任务
app.delete('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const [deletedTodo] = await db
      .delete(todos)
      .where(eq(todos.id, parseInt(id, 10)))
      .returning();

    if (deletedTodo) {
      res.status(204).send(); // 204 No Content
    } else {
      res.status(404).json({ error: 'Todo not found' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to delete todo' });
  }
});


// --- 启动服务器 ---
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
