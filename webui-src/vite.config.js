import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  base: './',
  plugins: [vue()],
  build: {
    outDir: '../webroot',
    emptyOutDir: true,
    assetsDir: 'assets',
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        entryFileNames: 'assets/app-[hash].js',
        chunkFileNames: 'assets/chunk-[hash].js',
        assetFileNames: 'assets/[name]-[hash][extname]',
        manualChunks: { vue: ['vue'] },
      },
    },
  },
})
