import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from 'path';

// Detect if we're in Tauri mode or web mode
const isTauriMode = process.env.TAURI_ENV_PLATFORM !== undefined;

// https://vitejs.dev/config/
export default defineConfig(async () => ({
  plugins: [react()],

  // Vite options tailored for Tauri development and only applied in `tauri dev` or `tauri build`
  // prevent vite from obscuring rust errors
  clearScreen: false,
  
  // Base path for subdomain deployment
  base: process.env.VITE_BASE_PATH || '/',
  
  // Module resolution: Use mocks for Tauri APIs in web mode
  resolve: {
    alias: isTauriMode ? {} : {
      '@tauri-apps/api/core': resolve(__dirname, 'src/mocks/@tauri-apps/api/core.ts'),
      '@tauri-apps/api/event': resolve(__dirname, 'src/mocks/@tauri-apps/api/event.ts'),
      '@tauri-apps/api/webviewWindow': resolve(__dirname, 'src/mocks/@tauri-apps/api/webviewWindow.ts'),
    },
  },

  // tauri expects a fixed port, fail if that port is not available
  server: {
    port: 1421,
    strictPort: true,
    watch: {
      // 3. tell vite to ignore watching `src-tauri`
      ignored: ["**/src-tauri/**"],
    },
  },
  build: {
    // Output directory for static site
    outDir: 'dist',
    // Ensure assets are correctly referenced
    assetsDir: 'assets',
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        settings: resolve(__dirname, 'settings.html'),
        shortcuts: resolve(__dirname, 'shortcuts.html'),
      },
    },
  },
}));