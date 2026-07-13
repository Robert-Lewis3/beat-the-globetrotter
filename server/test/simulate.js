// Simulates phone players for an E2E test.
// Usage: node test/simulate.js <ROOMCODE> [playerCount] [correctRate]
//   correctRate: fraction of players that answer correctly (default 0.75)
// Players answer 0.3-1.2s after each question appears. Knows the placeholder
// answer key so it can answer correctly on purpose.

const WebSocket = require('ws');

const SERVER = process.env.GT_SERVER || 'ws://localhost:3000';
const room = process.argv[2];
const count = parseInt(process.argv[3] || '4', 10);
const correctRate = parseFloat(process.argv[4] || '0.75');
if (!room) { console.error('usage: node test/simulate.js ROOMCODE [count] [correctRate]'); process.exit(2); }

// question-text fragment -> correct answer (MC: option text, open: typed text)
const KEY = [
  ['Great Wall', 'China'],
  ['Eurozone', 'Euro'],
  ['amphitheater', 'the colosseum'],
  ['single country', 'Australia'],
  ['Christ the Redeemer', 'Rio de Janeiro'],
  ['Petra', 'Jordan'],
  ['bell', 'Big Ben'],
  ['Bali', 'indonesia!'],
  ['most-visited', 'France'],
  ['nonstop', 'Singapore'],
  ['Royal Caribbean', 'Cruise ships'],
  ['tallest building', 'Burj Khalifa, Dubai'],
  ['ocean', 'Pacific'],
  ['Everest', 'China'],
  ['smallest country', 'vatican city'],
];

const WRONG_OPEN = 'the moon';
let done = 0;

function makePlayer(i) {
  const shouldBeCorrect = i < Math.round(count * correctRate);
  const ws = new WebSocket(SERVER);
  let lastQ = -1;

  ws.on('open', () => ws.send(JSON.stringify({ type: 'join', room, name: 'BOT' + (i + 1) })));
  ws.on('message', (raw) => {
    const msg = JSON.parse(raw.toString());
    if (msg.type === 'joined') console.log(`[bot${i + 1}] joined as ${msg.name}`);
    if (msg.type === 'error') { console.error(`[bot${i + 1}] SERVER ERROR: ${msg.error}`); process.exit(1); }
    if (msg.type !== 'state') return;
    const st = msg.payload || {};
    if (st.phase === 'question' && st.qId !== lastQ) {
      lastQ = st.qId;
      const delay = 300 + Math.random() * 900;
      setTimeout(() => answer(st), delay);
    }
    if (st.phase === 'reveal' && st.you) {
      console.log(`[bot${i + 1}] ${st.you.correct ? 'correct' : 'wrong'} (+${st.you.points || 0})`);
    }
    if (st.phase === 'end') {
      console.log(`[bot${i + 1}] end: victory=${st.victory} you=${JSON.stringify(st.you)}`);
      ws.close();
      if (++done === count) process.exit(0);
    }
  });

  function answer(st) {
    const entry = KEY.find(([frag]) => (st.text || '').includes(frag));
    let ans;
    if (st.kind === 'mc') {
      const correctIdx = entry ? (st.options || []).findIndex(o => o === entry[1]) : 0;
      if (shouldBeCorrect && correctIdx >= 0) ans = correctIdx;
      else ans = (correctIdx + 1 + Math.floor(Math.random() * 3)) % 4; // deliberately wrong
    } else {
      ans = shouldBeCorrect && entry ? entry[1] : WRONG_OPEN;
    }
    ws.send(JSON.stringify({ type: 'answer', answer: ans }));
  }

  ws.on('error', (e) => console.error(`[bot${i + 1}] error`, e.message));
}

for (let i = 0; i < count; i++) setTimeout(() => makePlayer(i), i * 150);
