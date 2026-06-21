// backend/models/Reservation.js
// ============================================================
// RESERVATION MODEL — Stores every parking booking made by users.
// A reservation links a User to a Spot in a Mall for a time range.
// Status flow: pending → active → completed/cancelled
//   - 'pending': User booked but hasn't verified arrival yet
//   - 'active': User verified their plate and is parked
//   - 'completed': Reservation ended normally or user left early
//   - 'cancelled': User or system cancelled the booking
// ============================================================
const mongoose = require('mongoose');

const ReservationSchema = new mongoose.Schema({

  // --- Core References (who, where, which mall) ---
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  spotId: { type: mongoose.Schema.Types.ObjectId, ref: 'Spot', required: true },
  mallId: { type: mongoose.Schema.Types.ObjectId, ref: 'Mall', required: true },

  // --- Booking Details ---
  // The car plate entered during booking (verified again on arrival)
  carPlate: { type: String, required: true },
  // Scheduled start and end times chosen by the user
  startTime: { type: Date, required: true },
  endTime: { type: Date, required: true },

  // --- Status Tracking ---
  // Current state of the reservation (see flow above)
  // 'overtime': Time has expired but car is still in the spot (sensor still active)
  status: { 
    type: String, 
    enum: ['pending', 'active', 'completed', 'cancelled', 'overtime'], 
    default: 'pending' 
  },

  // --- Payment & Rewards ---
  // Total cost in local currency (calculated as: hours × pricePerHour - discounts)
  // Setter prevents string values from breaking calculations
  amount: { 
    type: Number, 
    default: 0,
    set: (v) => typeof v === 'string' ? parseFloat(v) || 0 : v
  },
  // Reward points earned for this booking (≈10 points per hour)
  pointsEarned: { type: Number, default: 0 },
  // If a promo code was applied, store it here for records
  promoCodeUsed: { type: String },

  // --- Timing ---
  // The actual time the user verified arrival (may differ from startTime)
  actualStartTime: { type: Date },
  // Duration in minutes (used to recalculate endTime when user arrives late)
  durationMinutes: { type: Number },

  // --- Notification Flags ---
  // Prevents sending the same arrival reminder twice
  notified15: { type: Boolean, default: false },  // 15-minute reminder sent?
  notified30: { type: Boolean, default: false },  // 30-minute warning sent?

  // Expiration / Ending Notifications
  notifiedEnd30: { type: Boolean, default: false },
  notifiedEnd15: { type: Boolean, default: false },
  notifiedEnd5: { type: Boolean, default: false },
  notifiedEnd0: { type: Boolean, default: false }, // Final expiration warning

  // --- IoT / Sensor State ---
  // Set to true when the ESP32 sensor detects a car inside the spot
  carEntered: { type: Boolean, default: false },
  // Set to true when the server sends OPEN_GATE command to ESP32
  gateOpened: { type: Boolean, default: false },
  // Set to true when the car leaves and user says "No, keeping my spot"
  // User must re-enter their plate number before the gate opens again
  needsReverify: { type: Boolean, default: false },
  // Set to true once an overtime alert has been sent to admins/support.
  // Prevents the same alert from firing on every sync cycle.
  overtimeAlertSent: { type: Boolean, default: false },

  // --- Timestamps ---
  createdAt: { type: Date, default: Date.now }
});

// --- Database Indexes (speed up common queries) ---
ReservationSchema.index({ userId: 1 });                // Find all reservations for a user
ReservationSchema.index({ createdAt: -1 });             // Sort by newest first
ReservationSchema.index({ userId: 1, createdAt: -1 });  // User activity feed (sorted)
ReservationSchema.index({ status: 1, endTime: 1 });     // Background sync job queries

module.exports = mongoose.model('Reservation', ReservationSchema);