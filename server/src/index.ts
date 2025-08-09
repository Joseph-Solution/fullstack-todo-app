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
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 5678;

// --- API 路由 ---

// GET /health - 专用的健康检查路由
app.get('/health', (req, res) => {
  res.status(200).send('OK'); // 只返回一个简单的成功响应
});

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

// ... 其他 API 路由保持不变 ...
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

app.delete('/api/todos/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const [deletedTodo] = await db
      .delete(todos)
      .where(eq(todos.id, parseInt(id, 10)))
      .returning();

    if (deletedTodo) {
      res.status(204).send();
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