'use client';

import { useState, useEffect } from 'react';

// 使用相对路径，这样它会自动使用当前网站的域名
const API_BASE_URL = '/api';

// ... 文件的其余部分保持不变 ...
// (下面的代码和你之前的版本是一样的，但为了完整性，请全部复制)

interface Todo {
  id: number;
  text: string;
  completed: boolean;
}

export default function HomePage() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [inputText, setInputText] = useState('');

  useEffect(() => {
    const fetchTodos = async () => {
      try {
        const response = await fetch(`${API_BASE_URL}/todos`);
        const data = await response.json();
        setTodos(data);
      } catch (error) {
        console.error('Failed to fetch todos:', error);
      }
    };

    fetchTodos();
  }, []);

  const handleAddTask = async (e: React.FormEvent) => {
    e.preventDefault();
    if (inputText.trim() === '') return;

    try {
      const response = await fetch(`${API_BASE_URL}/todos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: inputText }),
      });
      const newTodo = await response.json();
      setTodos([...todos, newTodo]);
      setInputText('');
    } catch (error) {
      console.error('Failed to add todo:', error);
    }
  };

  const handleToggleTask = async (id: number) => {
    const todoToUpdate = todos.find(todo => todo.id === id);
    if (!todoToUpdate) return;

    try {
      const response = await fetch(`${API_BASE_URL}/todos/${id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ completed: !todoToUpdate.completed }),
      });
      const updatedTodo = await response.json();
      setTodos(
        todos.map(todo => (todo.id === id ? updatedTodo : todo))
      );
    } catch (error) {
      console.error('Failed to toggle todo:', error);
    }
  };

  const handleDeleteTask = async (id: number) => {
    try {
      await fetch(`${API_BASE_URL}/todos/${id}`, {
        method: 'DELETE',
      });
      setTodos(todos.filter(todo => todo.id !== id));
    } catch (error) {
      console.error('Failed to delete todo:', error);
    }
  };

  return (
    <main className="flex min-h-screen flex-col items-center p-24 bg-gray-900 text-white">
      <div className="w-full max-w-md">
        <h1 className="text-5xl font-bold text-center mb-8 text-cyan-400">
          Todo List
        </h1>

        <form onSubmit={handleAddTask} className="flex gap-4 mb-8">
          <input
            type="text"
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            placeholder="从数据库添加任务..."
            className="flex-grow p-3 rounded-lg bg-gray-800 border border-gray-700 focus:outline-none focus:ring-2 focus:ring-cyan-500"
          />
          <button
            type="submit"
            className="bg-cyan-500 hover:bg-cyan-600 text-white font-bold py-3 px-6 rounded-lg transition-colors"
          >
            添加
          </button>
        </form>

        <div className="space-y-4">
          {todos.map((todo) => (
            <div
              key={todo.id}
              className="flex items-center justify-between p-4 bg-gray-800 rounded-lg shadow"
            >
              <span
                className={`text-lg cursor-pointer ${
                  todo.completed ? 'line-through text-gray-500' : ''
                }`}
                onClick={() => handleToggleTask(todo.id)}
              >
                {todo.text}
              </span>
              <div className="flex items-center gap-3">
                <button
                  onClick={() => handleToggleTask(todo.id)}
                  className={
                    todo.completed
                      ? 'text-yellow-500 hover:text-yellow-400'
                      : 'text-green-500 hover:text-green-400'
                  }
                >
                  {todo.completed ? '撤销' : '完成'}
                </button>
                <button
                  onClick={() => handleDeleteTask(todo.id)}
                  className="text-red-500 hover:text-red-400"
                >
                  删除
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}