import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    // Suppress chunk size warning - our bundle is fine for a single-page app
    chunkSizeWarningLimit: 600,
  },
})
