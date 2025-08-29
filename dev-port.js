#!/usr/bin/env node

import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const port = process.argv[2] || '1421';
const configPath = path.join(__dirname, 'src-tauri', 'tauri.conf.json');
const backupPath = configPath + '.backup';

// Backup original config if it doesn't exist
if (!fs.existsSync(backupPath)) {
  fs.copyFileSync(configPath, backupPath);
}

// Read and modify config
const config = JSON.parse(fs.readFileSync(backupPath, 'utf8'));
config.build.devUrl = `http://localhost:${port}`;
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

// Set environment and run tauri dev
process.env.VITE_PORT = port;
const child = spawn('pnpm', ['tauri', 'dev'], {
  stdio: 'inherit',
  shell: true,
  env: { ...process.env, VITE_PORT: port }
});

// Cleanup on exit
const cleanup = () => {
  console.log('\n🧹 Restoring original config...');
  fs.copyFileSync(backupPath, configPath);
  process.exit(0);
};

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);

child.on('close', (code) => {
  cleanup();
});