// backend/scripts/simulate_iot.js
const WebSocket = require('ws');
const readline = require('readline');

const WS_URL = 'ws://localhost:5000/ws/iot';
const SPOT_ID = '69cd86659c1a5e779d63af04'; // Default spot ID matching Arduino sketch and seeded database

console.log('==================================================');
console.log('🤖 iPARK - IoT Device WebSocket Simulator');
console.log('==================================================');
console.log(`Connecting to: ${WS_URL}`);
console.log(`Simulating Spot ID: ${SPOT_ID}`);

const ws = new WebSocket(WS_URL);

// Set up CLI interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

ws.on('open', () => {
  console.log('\n🟢 WebSocket connection opened successfully!');
  
  // Register the device
  const regMsg = {
    action: 'register',
    spotId: SPOT_ID
  };
  ws.send(JSON.stringify(regMsg));
  console.log(`📡 Sent action: "register" for spotId: ${SPOT_ID}`);
  
  printMenu();
});

ws.on('message', (message) => {
  try {
    const data = JSON.parse(message.toString());
    console.log(`\n📥 [Server -> IoT] Received command:`, data);

    const { action } = data;

    if (action === 'OPEN_GATE') {
      console.log('🔏 [SIMULATOR] Rotating servo to 90 degrees... 🟢 GATE OPENED');
      // Send acknowledgement
      const ack = {
        action: 'gate_status',
        spotId: SPOT_ID,
        status: 'OPEN'
      };
      ws.send(JSON.stringify(ack));
      console.log('📤 [IoT -> Server] Sent acknowledgement: Gate is OPEN');
    } else if (action === 'CLOSE_GATE') {
      console.log('🔏 [SIMULATOR] Rotating servo to 0 degrees... 🔴 GATE CLOSED');
      // Send acknowledgement
      const ack = {
        action: 'gate_status',
        spotId: SPOT_ID,
        status: 'CLOSED'
      };
      ws.send(JSON.stringify(ack));
      console.log('📤 [IoT -> Server] Sent acknowledgement: Gate is CLOSED');
    }
  } catch (err) {
    console.error('❌ Error parsing incoming message:', err.message);
  }
  printMenu();
});

ws.on('close', () => {
  console.log('\n🔴 WebSocket connection closed.');
  process.exit();
});

ws.on('error', (err) => {
  console.error('❌ WebSocket error:', err.message);
});

function printMenu() {
  console.log('\n--- Simulator Control Menu ---');
  console.log('Press [1] to simulate: Car Enter Spot (Occupied = true)');
  console.log('Press [2] to simulate: Car Leave Spot (Occupied = false)');
  console.log('Press [q] to quit simulator');
  process.stdout.write('Choose an option: ');
}

// Handle user keyboard inputs
readline.emitKeypressEvents(process.stdin);
if (process.stdin.isTTY) {
  process.stdin.setRawMode(true);
}

process.stdin.on('keypress', (str, key) => {
  if (key.ctrl && key.name === 'c' || str === 'q') {
    console.log('\nExiting simulator...');
    process.exit();
  }

  if (str === '1') {
    console.log('\n🚗 Simulating: Car ENTERED parking spot...');
    const msg = {
      action: 'status_change',
      spotId: SPOT_ID,
      occupied: true
    };
    ws.send(JSON.stringify(msg));
    console.log('📤 [IoT -> Server] Sent: occupied = true');
  } else if (str === '2') {
    console.log('\n🚙 Simulating: Car LEFT parking spot...');
    const msg = {
      action: 'status_change',
      spotId: SPOT_ID,
      occupied: false
    };
    ws.send(JSON.stringify(msg));
    console.log('📤 [IoT -> Server] Sent: occupied = false');
  }
});
