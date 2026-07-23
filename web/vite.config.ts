import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath, URL } from 'node:url'

// Project is deployed to GitHub Pages at https://<user>.github.io/Ebonveil/
// so assets must be served from the /Ebonveil/ base. Override with VITE_BASE if
// you fork under a different repo name.
const base = process.env.VITE_BASE ?? '/Ebonveil/'

// https://vite.dev/config/
export default defineConfig({
  base,
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})
