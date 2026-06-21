// backend/models/Spot.js
// ============================================================
// SPOT MODEL — Represents a single parking spot inside a mall.
// Each mall has multiple spots (e.g., A-1, A-2, A-3...).
// The 'status' field controls the color shown in the app:
//   - 'green': Available for reservation
//   - 'red': Currently booked/occupied (someone is arriving or parked)
//   - 'yellow': Booking is about to end (within 15 minutes of endTime)
//   - 'disabled': Manually taken offline by admin
// The status is automatically updated by the background sync job in server.js
// ============================================================
const mongoose = require('mongoose');

const SpotSchema = new mongoose.Schema({
  // Which mall this spot belongs to
  mallId: { type: mongoose.Schema.Types.ObjectId, ref: 'Mall', required: true },
  // Display name shown in the app (e.g., "A-1", "A-2")
  spotNumber: { type: String, required: true },
  // Current color/status — determines if users can book this spot
  status: { 
    type: String, 
    enum: ['green', 'yellow', 'red', 'disabled'], 
    default: 'green' 
  },
  // Which user currently has this spot reserved (if any)
  reservedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  // Link to the active reservation for this spot (if any)
  reservationId: { type: mongoose.Schema.Types.ObjectId, ref: 'Reservation' },
  // When this spot's status was last changed
  lastUpdated: { type: Date, default: Date.now }
});

// --- Database Indexes ---
SpotSchema.index({ mallId: 1 });   // Quickly find all spots in a mall
SpotSchema.index({ status: 1 });   // Filter spots by color/status

module.exports = mongoose.model('Spot', SpotSchema);