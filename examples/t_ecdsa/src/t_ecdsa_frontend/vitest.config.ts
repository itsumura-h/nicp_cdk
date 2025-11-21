import { defineConfig } from 'vitest/config';
import path from 'node:path';
import { config } from 'dotenv';

// vite.config.tsと同じように.envファイルを読み込む
config({ path: `${process.cwd()}/../../.env` });

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    testTimeout: 60000, // ICPキャニスターの呼び出しには時間がかかる可能性があるため
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});

