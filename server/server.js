// Beat The Globetrotter — relay server
// Rooms are created by a host (the Godot game). Players join from phones via
// the QR-coded URL. The server holds no game logic: it relays player joins and
// answers to the host, and broadcasts host state snapshots to every phone.

const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const WebSocket = require('ws');
const QRCode = require('qrcode');

const PORT = process.env.PORT || 3000;
const PUBLIC_DIR = path.join(__dirname, 'public');
const ROOM_TTL_NO_HOST_MS = 5 * 60 * 1000;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.ttf': 'font/ttf',
  '.ico': 'image/x-icon',
};

/** rooms: code -> { host: ws|null, players: Map<playerId, {ws, name, connected}>, lastState, hostLostAt } */
const rooms = new Map();

function makeRoomCode() {
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // no I/O to avoid confusion
  let code;
  do {
    code = Array.from({ length: 4 }, () => letters[Math.floor(Math.random() * letters.length)]).join('');
  } while (rooms.has(code));
  return code;
}

function send(ws, obj) {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
}

function roomOf(ws) {
  return ws._roomCode ? rooms.get(ws._roomCode) : undefined;
}

// ---------------------------------------------------------------- HTTP
const server = http.createServer(async (req, res) => {
  const u = new URL(req.url, `http://${req.headers.host}`);

  if (u.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    return res.end('ok');
  }

  if (u.pathname === '/qr') {
    const data = u.searchParams.get('data');
    if (!data || data.length > 500) {
      res.writeHead(400);
      return res.end('missing data');
    }
    try {
      const png = await QRCode.toBuffer(data, {
        type: 'png',
        width: 480,
        margin: 1,
        color: { dark: '#0a0a1a', light: '#ffffff' },
      });
      res.writeHead(200, { 'Content-Type': 'image/png', 'Cache-Control': 'no-store' });
      return res.end(png);
    } catch (e) {
      res.writeHead(500);
      return res.end('qr error');
    }
  }

  // Static files; every unknown path serves the player page so /JOIN links work.
  let file = u.pathname === '/' ? '/index.html' : u.pathname;
  file = path.normalize(file).replace(/^(\.\.[/\\])+/, '');
  let full = path.join(PUBLIC_DIR, file);
  if (!full.startsWith(PUBLIC_DIR) || !fs.existsSync(full) || fs.statSync(full).isDirectory()) {
    full = path.join(PUBLIC_DIR, 'index.html');
  }
  const ext = path.extname(full);
  res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
  fs.createReadStream(full).pipe(res);
});

// ---------------------------------------------------------------- WebSocket
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }

    switch (msg.type) {
      // ---- host messages -------------------------------------------------
      case 'host_create': {
        const code = makeRoomCode();
        rooms.set(code, { host: ws, players: new Map(), lastState: null, hostLostAt: null });
        ws._roomCode = code;
        ws._isHost = true;
        send(ws, { type: 'room_created', code });
        break;
      }
      case 'host_reclaim': { // host reconnected after a drop
        const room = rooms.get(msg.code);
        if (!room) return send(ws, { type: 'error', error: 'no_such_room' });
        room.host = ws;
        room.hostLostAt = null;
        ws._roomCode = msg.code;
        ws._isHost = true;
        const players = [...room.players.entries()]
          .map(([id, p]) => ({ playerId: id, name: p.name, connected: p.connected }));
        send(ws, { type: 'room_reclaimed', code: msg.code, players });
        break;
      }
      case 'state': { // broadcast snapshot to all players (+ optional per-player extras)
        const room = roomOf(ws);
        if (!room || room.host !== ws) return;
        room.lastState = msg.shared || {};
        for (const [id, p] of room.players) {
          if (!p.connected) continue;
          const payload = { ...room.lastState };
          if (msg.perPlayer && msg.perPlayer[id] !== undefined) payload.you = msg.perPlayer[id];
          send(p.ws, { type: 'state', payload });
        }
        break;
      }
      case 'kick': {
        const room = roomOf(ws);
        if (!room || room.host !== ws) return;
        const p = room.players.get(msg.playerId);
        if (p) {
          send(p.ws, { type: 'kicked' });
          if (p.ws) p.ws.close();
          room.players.delete(msg.playerId);
        }
        break;
      }

      // ---- player messages -----------------------------------------------
      case 'join': {
        const code = String(msg.room || '').toUpperCase();
        const room = rooms.get(code);
        if (!room) return send(ws, { type: 'error', error: 'no_such_room' });
        const name = String(msg.name || 'PLAYER').trim().slice(0, 16).toUpperCase() || 'PLAYER';

        let playerId = msg.playerId;
        const existing = playerId && room.players.get(playerId);
        if (existing) {
          existing.ws = ws;
          existing.connected = true;
        } else {
          playerId = 'p' + Math.random().toString(36).slice(2, 10);
          room.players.set(playerId, { ws, name, connected: true });
        }
        ws._roomCode = code;
        ws._playerId = playerId;
        const player = room.players.get(playerId);
        send(ws, { type: 'joined', playerId, name: player.name, room: code });
        if (room.lastState) send(ws, { type: 'state', payload: room.lastState });
        send(room.host, {
          type: existing ? 'player_rejoined' : 'player_joined',
          playerId,
          name: player.name,
        });
        break;
      }
      case 'answer': {
        const room = roomOf(ws);
        if (!room || !ws._playerId) return;
        send(room.host, {
          type: 'player_answer',
          playerId: ws._playerId,
          answer: msg.answer,        // option index (MC) or text (open-end)
          at: Date.now(),
        });
        break;
      }
    }
  });

  ws.on('close', () => {
    const room = roomOf(ws);
    if (!room) return;
    if (ws._isHost && room.host === ws) {
      room.host = null;
      room.hostLostAt = Date.now();
    } else if (ws._playerId) {
      const p = room.players.get(ws._playerId);
      if (p && p.ws === ws) {
        p.connected = false;
        send(room.host, { type: 'player_left', playerId: ws._playerId });
      }
    }
  });
});

// Heartbeat + hostless-room cleanup
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
  const now = Date.now();
  for (const [code, room] of rooms) {
    if (!room.host && room.hostLostAt && now - room.hostLostAt > ROOM_TTL_NO_HOST_MS) {
      for (const [, p] of room.players) if (p.ws) p.ws.close();
      rooms.delete(code);
    }
  }
}, 15000);

server.listen(PORT, () => {
  console.log(`Globetrotter relay listening on :${PORT}`);
});
