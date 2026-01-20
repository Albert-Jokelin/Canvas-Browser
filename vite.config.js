import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import electron from 'vite-plugin-electron'
import renderer from 'vite-plugin-electron-renderer'
import path from 'path'

export default defineConfig({
    plugins: [
        react(),
        electron([
            {
                entry: 'src/main/index.js',
                vite: {
                    build: {
                        outDir: 'dist-electron/main',
                        rollupOptions: {
                            external: ['better-sqlite3', 'electron']
                        }
                    }
                }
            },
            {
                entry: 'src/preload/index.js',
                vite: {
                    build: {
                        outDir: 'dist-electron/preload',
                        lib: {
                            entry: 'src/preload/index.js',
                            formats: ['cjs'],
                            fileName: () => 'index.cjs',
                        },
                        rollupOptions: {
                            external: ['electron']
                        }
                    }
                },
                onstart(options) {
                    options.reload()
                }
            }
        ]),
        renderer()
    ],
    resolve: {
        alias: {
            '@': path.resolve(__dirname, './src/renderer')
        }
    },
    build: {
        outDir: 'dist',
        emptyOutDir: true
    }
})
