/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  // Served from https://testtest126.github.io/poker/ (a repo-subpath GitHub Pages site,
  // not a custom domain) — without this, built asset URLs resolve from the domain root
  // and 404, producing a blank white page. Local dev (`npm run dev`) is unaffected; Vite
  // only applies `base` to the production build.
  base: '/poker/',
  plugins: [react(), tailwindcss()],
  test: {
    environment: 'node',
    include: ['src/engine/**/*.test.ts'],
  },
})
