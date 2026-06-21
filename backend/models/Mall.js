// backend/models/Mall.js
// ============================================================
// MALL MODEL — Represents a parking location (mall/building).
// Each mall contains multiple Spots. Admins can add/edit malls
// from the admin dashboard. Users see malls on the home screen.
// ============================================================
const mongoose = require('mongoose');

const MallSchema = new mongoose.Schema({
  // Display name shown in the app (e.g., "City Center Mall")
  name: { type: String, required: true },
  // City or area (e.g., "Baghdad", "Erbil") — used for display
  location: { type: String, required: true },
  // Short description shown on the mall detail page
  description: { type: String, default: '' },
  // Full street address
  address: { type: String },
  // Photo URL (stored in uploads/malls/ folder or external URL)
  photoUrl: { type: String },
  // Total number of parking spots in this mall
  // When admin changes this, spots are auto-created/deleted
  totalSpots: { type: Number, default: 0 },
  // Cost per hour in local currency — used to calculate reservation price
  pricePerHour: { type: Number, default: 0 },
  // When this mall was added to the system
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Mall', MallSchema);