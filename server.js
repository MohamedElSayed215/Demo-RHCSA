const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const pty = require('node-pty');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

app.use(express.static(path.join(__dirname, 'public')));

// Track sessions
const sessions = new Map();

// Max concurrent sessions
const MAX_SESSIONS = 20;

wss.on('connection', (ws, req) => {
  if (sessions.size >= MAX_SESSIONS) {
    ws.send(JSON.stringify({ type: 'error', data: 'الخادم ممتلئ حالياً. حاول لاحقاً.' }));
    ws.close();
    return;
  }

  const sessionId = uuidv4();
  console.log(`[${sessionId}] New connection from ${req.socket.remoteAddress}`);

  // Spawn a real bash shell
  let ptyProcess;
  try {
    ptyProcess = pty.spawn('bash', ['--login'], {
      name: 'xterm-256color',
      cols: 80,
      rows: 24,
      cwd: '/root',
      env: {
        ...process.env,
        TERM: 'xterm-256color',
        COLORTERM: 'truecolor',
        HOME: '/root',
        USER: 'root',
        SHELL: '/bin/bash',
        PS1: '[\\[\\033[1;32m\\]root\\[\\033[0m\\]@\\[\\033[1;34m\\]rhcsa-lab\\[\\033[0m\\] \\[\\033[1;33m\\]\\w\\[\\033[0m\\]]# ',
        LANG: 'en_US.UTF-8',
      }
    });
  } catch (err) {
    console.error('Failed to spawn pty:', err);
    ws.send(JSON.stringify({ type: 'error', data: 'فشل تشغيل الـ Terminal.' }));
    ws.close();
    return;
  }

  sessions.set(sessionId, { ws, ptyProcess });

  // Send terminal output to browser
  ptyProcess.onData((data) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'output', data }));
    }
  });

  ptyProcess.onExit(({ exitCode }) => {
    console.log(`[${sessionId}] Shell exited with code ${exitCode}`);
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'output', data: '\r\n\x1b[33m[shell exited — reload to restart]\x1b[0m\r\n' }));
    }
    sessions.delete(sessionId);
  });

  // Handle messages from browser
  ws.on('message', (rawMsg) => {
    try {
      const msg = JSON.parse(rawMsg);
      switch (msg.type) {
        case 'input':
          if (ptyProcess) ptyProcess.write(msg.data);
          break;
        case 'resize':
          if (ptyProcess && msg.cols && msg.rows) {
            ptyProcess.resize(Math.max(1, msg.cols), Math.max(1, msg.rows));
          }
          break;
        case 'ping':
          ws.send(JSON.stringify({ type: 'pong' }));
          break;
      }
    } catch (e) {
      console.error('Bad message:', e.message);
    }
  });

  ws.on('close', () => {
    console.log(`[${sessionId}] Disconnected`);
    if (ptyProcess) {
      try { ptyProcess.kill(); } catch(e) {}
    }
    sessions.delete(sessionId);
  });

  ws.on('error', (err) => {
    console.error(`[${sessionId}] WS error:`, err.message);
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', sessions: sessions.size });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 RHCSA Terminal Server running on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Shutting down...');
  sessions.forEach(({ ptyProcess }) => {
    try { ptyProcess.kill(); } catch(e) {}
  });
  server.close(() => process.exit(0));
});
