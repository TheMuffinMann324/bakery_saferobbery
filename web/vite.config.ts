import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'path'

export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
  resolve: { alias: { '@': path.resolve(import.meta.dirname, './src') } },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    chunkSizeWarningLimit: 800,
    license: { fileName: 'licenses.md' },
    rolldownOptions: {
      input: ['index.html', 'note.html', 'prompt.html'].map((file) => path.resolve(import.meta.dirname, file)),
    },
  },
})
