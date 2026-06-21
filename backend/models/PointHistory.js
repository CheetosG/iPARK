// backend/models/PointHistory.js
// ============================================================
// POINT HISTORY MODEL — Tracks every points transaction for a user.
// Positive amounts = points earned (from reservations)
// Negative amounts = points spent (redeemed for rewards)
// Users can see their point history in the Rewards screen.
// ============================================================
const mongoose = require('mongoose');

const PointHistorySchema = new mongoose.Schema({
  // Which user earned/spent these points
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  // Which mall the points were earned at (null for redemptions)
  mallId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Mall',
    index: true
  },
  // Number of points (positive = earned, negative = redeemed)
  amount: {
    type: Number,
    required: true
  },
  // Description (e.g., "Reservation at City Center Mall" or "Redeemed: 25% Discount")
  reason: {
    type: String,
    required: true
  },
  // When this transaction happened
  createdAt: {
    type: Date,
    default: Date.now,
    index: true
  }
});

module.exports = mongoose.model('PointHistory', PointHistorySchema);
