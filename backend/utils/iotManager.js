// backend/utils/iotManager.js
// ============================================================
// IOT MANAGER — The bridge between ESP32 hardware and the server.
//
// This module manages WebSocket connections from ESP32 devices.
// Each ESP32 connects via ws://server:5000/ws/iot and registers
// itself for a specific parking spot.
//
// ARCHITECTURE:
//   ESP32 → WebSocket → iotManager → MongoDB + Socket.IO → Flutter App
//
// Three main functions:
//   1. Register: ESP32 tells us which spot it controls
//   2. Status Change: ESP32 reports if a car is detected (occupied/empty)
//   3. Gate Control: Server sends OPEN_GATE/CLOSE_GATE commands to ESP32
//
// The activeIotDevices Map stores: spotId → WebSocket connection
// This allows us to send commands to a specific ESP32 by spot ID.
// ============================================================
const { WebSocketServer } = require('ws');
const Reservation = require('../models/Reservation');
const Spot = require('../models/Spot');

// --- In-memory store: spotId (String) → WebSocket connection ---
// When we need to send a command to a specific ESP32, we look it up here
const activeIotDevices = new Map();

// Reference to Socket.IO server (used to emit events to Flutter app)
let ioInstance = null;

// --- Create WebSocket Server (no HTTP server — uses upgrade from Express) ---
const wss = new WebSocketServer({ noServer: true });

// ============================================================
// WEBSOCKET CONNECTION HANDLER
// Called when an ESP32 connects to ws://server:5000/ws/iot
// ============================================================
wss.on('connection', (ws) => {
  console.log('[IoT MANAGER] New ESP32 WebSocket connection established');

  // ----------------------------------------------------------
  // MESSAGE HANDLER — Processes messages from ESP32 devices
  // ----------------------------------------------------------
  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log(`[IoT MANAGER] Message received from ESP32:`, data);

      const { action } = data;

      // ----------------------------------------------------------
      // ACTION: "register"
      // ESP32 tells us which parking spot it controls.
      // We save the WebSocket connection in activeIotDevices Map.
      // After this, we can send OPEN_GATE/CLOSE_GATE to this spot.
      // ----------------------------------------------------------
      if (action === 'register') {
        const { spotId } = data;
        if (!spotId) {
          ws.send(JSON.stringify({ error: 'Missing spotId in registration' }));
          return;
        }

        // Store the spotId on the websocket object for cleanup when it disconnects
        ws.spotId = spotId.toString();
        activeIotDevices.set(ws.spotId, ws);
        
        console.log(`[IoT MANAGER] IoT device successfully registered for Spot ID: ${ws.spotId}`);
        ws.send(JSON.stringify({ success: true, message: `Registered for spot ${ws.spotId}` }));
        return;
      }

      // ----------------------------------------------------------
      // ACTION: "status_change"
      // ESP32 sensors detected a change in car presence.
      // occupied=true → car entered the spot
      // occupied=false → car left the spot → ask user if leaving early
      // ----------------------------------------------------------
      if (action === 'status_change') {
        const { spotId, occupied } = data;
        if (!spotId) return;

        // Fetch spot details to print human-readable name in terminal
        const spot = await Spot.findById(spotId).populate('mallId', 'name');
        const spotName = spot 
          ? `${spot.mallId ? spot.mallId.name : 'Mall'} Spot ${spot.spotNumber || spot.number || spotId}` 
          : `Spot ${spotId}`;
        const statusText = occupied ? "CAR DETECTED (OCCUPIED)" : "NO CAR DETECTED (FREE)";
        
        console.log(`[IoT MANAGER] ${spotName}: ${statusText}`);

        // -------------------------------------------------------
        // RESERVATION LOOKUP — Two-stage search
        //
        // Stage 1: Exact match by spotId (single-spot setup)
        // Stage 2: If no exact match, search by mallId (multi-spot
        //          single-gate setup where the IR sensor's spotId
        //          differs from the gate's spotId that the reservation
        //          was booked against).
        // -------------------------------------------------------
        let reservation = await Reservation.findOne({
          spotId: spotId.toString(),
          status: { $in: ['active', 'overtime', 'pending'] }
        });

        if (!reservation && spot && spot.mallId) {
          // Fallback: find any active reservation in the same mall
          // This covers two-spot / one-gate layouts
          const spotsInMall = await Spot.find({ mallId: spot.mallId._id }).select('_id');
          const spotIdsInMall = spotsInMall.map(s => s._id.toString());
          reservation = await Reservation.findOne({
            spotId: { $in: spotIdsInMall },
            status: { $in: ['active', 'overtime', 'pending'] }
          });
          if (reservation) {
            console.log(`[IoT MANAGER] No exact spotId match. Found reservation via mall fallback: ${reservation._id} (spotId: ${reservation.spotId})`);
          }
        }

        if (!reservation) {
          console.log(`[IoT MANAGER] No active/pending reservation found for spot ${spotId} or its mall. Status update ignored.`);
          return;
        }

        if (occupied === true) {
          // Car ENTERED the spot → update the reservation record
          if (!reservation.carEntered) {
            reservation.carEntered = true;
            await reservation.save();
            console.log(`[IoT MANAGER] Car detected inside spot ${spotId}. Set carEntered = true for reservation ${reservation._id}`);
          }
        } else if (occupied === false) {
          // Car LEFT the spot
          if (reservation.carEntered) {
            // -------------------------------------------------------
            // OVERTIME CASE: Time already expired, car finally left.
            // Auto-complete the reservation — no need to ask the user.
            // -------------------------------------------------------
            if (reservation.status === 'overtime') {
              console.log(`[IoT MANAGER] ✅ Overtime car left spot ${spotId}. Auto-completing reservation ${reservation._id}.`);
              reservation.carEntered = false;
              reservation.status = 'completed';
              await reservation.save();

              // Notify the admin dashboard that the overtime is resolved
              if (ioInstance) {
                ioInstance.emit('overtime_resolved', {
                  reservationId: reservation._id.toString(),
                  spotId: spotId.toString(),
                  carPlate: reservation.carPlate,
                  message: `✅ Overtime resolved: Car left ${spotName}. Reservation completed.`
                });
              }
              console.log(`[IoT MANAGER] Overtime resolved for ${spotName}.`);
              return;
            }

            // -------------------------------------------------------
            // NORMAL CASE: Reservation is still active, car left early.
            // Prompt the user via app: "Are you leaving early?"
            // -------------------------------------------------------
            console.log(`[IoT MANAGER] Car left spot ${spotId} (reservation still active). Prompting user ${reservation.userId} to ask if they are leaving early.`);
            
            if (ioInstance) {
              // Emit to the specific user's room (user sees a popup dialog)
              ioInstance.to(reservation.userId.toString()).emit('ask_leave_early', {
                reservationId: reservation._id.toString(),
                spotId: spotId.toString()
              });
            } else {
              console.warn('[IoT MANAGER] Socket.IO instance not initialized in iotManager.');
            }
          } else {
            // carEntered was false — car left without being tracked as entered.
            // This can happen if the server restarted mid-session. 
            // Just log it; don't prompt the user.
            console.log(`[IoT MANAGER] Car left spot ${spotId} but carEntered was false. Skipping leave-early prompt.`);
          }
        }
        return;
      }

      // ----------------------------------------------------------
      // ACTION: "gate_status"
      // ESP32 confirms the gate actually opened or closed.
      // Updates the reservation record so the app knows gate state.
      // ----------------------------------------------------------
      if (action === 'gate_status') {
        const { spotId, status } = data;
        if (spotId) {
          console.log(`[IoT MANAGER] Gate status for spot ${spotId} reported as: ${status}`);
          // Update the gateOpened flag on the reservation
          const reservation = await Reservation.findOne({ spotId: spotId.toString(), status: 'active' });
          if (reservation) {
            reservation.gateOpened = (status === 'OPEN');
            await reservation.save();
          }
        }
        return;
      }

    } catch (err) {
      console.error('[IoT MANAGER] Error handling message:', err.message);
    }
  });

  // ----------------------------------------------------------
  // DISCONNECT HANDLER — ESP32 lost connection (WiFi drop, power off)
  // Remove it from our active devices Map
  // ----------------------------------------------------------
  ws.on('close', () => {
    if (ws.spotId) {
      activeIotDevices.delete(ws.spotId);
      console.log(`[IoT MANAGER] IoT device disconnected for spot: ${ws.spotId}`);
    } else {
      console.log('[IoT MANAGER] Unregistered IoT device disconnected');
    }
  });

  // ----------------------------------------------------------
  // ERROR HANDLER — Log WebSocket errors
  // ----------------------------------------------------------
  ws.on('error', (error) => {
    console.error(`[IoT MANAGER] WebSocket error on spot ${ws.spotId || 'unknown'}:`, error.message);
  });
});

// ============================================================
// INIT — Stores the Socket.IO reference so we can emit events
// Called once during server startup in server.js
// ============================================================
const init = (io) => {
  ioInstance = io;
  console.log('[IoT MANAGER] Initialized with Socket.IO instance');
};

// ============================================================
// HANDLE UPGRADE — Routes WebSocket upgrade requests to our WSS
// Called by server.js when a request comes to /ws/iot
// ============================================================
const handleUpgrade = (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
};

// ============================================================
// OPEN GATE — Sends OPEN_GATE command to the ESP32 for a spot
// The ESP32 will rotate the servo to 90° (open position)
// Returns true if the command was sent, false if no device connected
// ============================================================
const openGate = (spotId) => {
  const ws = activeIotDevices.get(spotId.toString());
  if (ws && ws.readyState === ws.OPEN) {
    console.log(`[IoT MANAGER] Sending OPEN_GATE command to spot: ${spotId}`);
    ws.send(JSON.stringify({ action: 'OPEN_GATE', spotId: spotId.toString() }));
    return true;
  }
  console.warn(`[IoT MANAGER] Cannot open gate. No active IoT device connected for spot: ${spotId}`);
  return false;
};

// ============================================================
// CLOSE GATE — Sends CLOSE_GATE command to the ESP32 for a spot
// The ESP32 will rotate the servo to 0° (closed position)
// Returns true if the command was sent, false if no device connected
// ============================================================
const closeGate = (spotId) => {
  const ws = activeIotDevices.get(spotId.toString());
  if (ws && ws.readyState === ws.OPEN) {
    console.log(`[IoT MANAGER] Sending CLOSE_GATE command to spot: ${spotId}`);
    ws.send(JSON.stringify({ action: 'CLOSE_GATE', spotId: spotId.toString() }));
    return true;
  }
  console.warn(`[IoT MANAGER] Cannot close gate. No active IoT device connected for spot: ${spotId}`);
  return false;
};

// --- Export all functions for use by controllers and server.js ---
module.exports = {
  init,
  handleUpgrade,
  openGate,
  closeGate,
  wss
};
