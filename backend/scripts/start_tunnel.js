const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const PORT = 5000;
const API_CONFIG_PATH = path.join(__dirname, '../../frontend/lib/services/api_config.dart');
const NGROK_URL_PATH = path.join(__dirname, '../ngrok_url.txt');

console.log('\x1b[36m%s\x1b[0m', '===============================================');
console.log('\x1b[36m%s\x1b[0m', '   iPARK AUTOMATED TUNNEL & CONFIG SYNC');
console.log('\x1b[36m%s\x1b[0m', '===============================================');

// 1. Start the backend server
console.log('[Runner] Starting Backend Server...');
const server = spawn('node', ['server.js'], { 
  cwd: path.join(__dirname, '..'), 
  env: process.env,
  shell: true 
});

server.stdout.on('data', (data) => {
  const lines = data.toString().trim().split('\n');
  lines.forEach(line => console.log(`[Backend] ${line}`));
});

server.stderr.on('data', (data) => {
  const lines = data.toString().trim().split('\n');
  lines.forEach(line => console.error(`\x1b[31m[Backend Error] ${line}\x1b[0m`));
});

// 2. Start localtunnel
console.log(`[Runner] Starting Public Tunnel on Port ${PORT}...`);
const lt = spawn('npx', ['localtunnel', '--port', PORT.toString()], { shell: true });

let tunnelUrl = '';

lt.stdout.on('data', (data) => {
  const output = data.toString().trim();
  
  // localtunnel outputs: "your url is: https://xxxx.localtunnel.me"
  const urlMatch = output.match(/your url is:\s*(https:\/\/[^\s]+)/i);
  if (urlMatch && urlMatch[1]) {
    tunnelUrl = urlMatch[1].trim();
    console.log('\x1b[32m%s\x1b[0m', `\n[Tunnel] SUCCESS: Public Tunnel is Active!`);
    console.log('\x1b[32m%s\x1b[0m', `[Tunnel] URL: ${tunnelUrl}\n`);
    updateConfigs(tunnelUrl);
  } else {
    console.log(`[Tunnel Info] ${output}`);
  }
});

lt.stderr.on('data', (data) => {
  console.error(`\x1b[33m[Tunnel Warning] ${data.toString().trim()}\x1b[0m`);
});

function updateConfigs(url) {
  // Update ngrok_url.txt
  try {
    fs.writeFileSync(NGROK_URL_PATH, url, 'utf8');
    console.log(`[Config] Sync: Updated ${path.basename(NGROK_URL_PATH)}`);
  } catch (err) {
    console.error(`[Config Error] Failed to write ${path.basename(NGROK_URL_PATH)}:`, err.message);
  }

  // Update api_config.dart
  try {
    if (fs.existsSync(API_CONFIG_PATH)) {
      let content = fs.readFileSync(API_CONFIG_PATH, 'utf8');
      
      // Locate the ngrokUrl line
      const regex = /static const String ngrokUrl = '[^']+'/g;
      if (regex.test(content)) {
        content = content.replace(regex, `static const String ngrokUrl = '${url}'`);
        fs.writeFileSync(API_CONFIG_PATH, content, 'utf8');
        console.log('\x1b[32m%s\x1b[0m', `[Config] Sync: Automatically updated Flutter api_config.dart!`);
        console.log('[Runner] System is ready. You can now build/run the Flutter app and hardware.');
      } else {
        console.warn(`\x1b[33m[Config Warning] Could not locate 'static const String ngrokUrl' declaration in api_config.dart\x1b[0m`);
      }
    } else {
      console.warn(`\x1b[33m[Config Warning] Flutter api_config.dart was not found at ${API_CONFIG_PATH}\x1b[0m`);
    }
  } catch (err) {
    console.error(`[Config Error] Failed to update Flutter configuration:`, err.message);
  }
}

// Ensure children terminate when the main process is terminated
process.on('SIGINT', () => {
  console.log('\n[Runner] Closing backend server and tunnel...');
  server.kill('SIGINT');
  lt.kill('SIGINT');
  process.exit(0);
});

process.on('exit', () => {
  server.kill();
  lt.kill();
});
