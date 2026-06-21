// backend/models/PromoCode.js
// ============================================================
// PROMO CODE MODEL — Stores discount codes created by admins.
// Users can enter a promo code during reservation to get a discount.
// Each code has a usage limit and tracks who already used it.
// ============================================================
const mongoose = require('mongoose');

const PromoCodeSchema = new mongoose.Schema({
  // The code string users type (e.g., "SUMMER25") — stored uppercase
  code: { type: String, required: true, unique: true },
  // Discount percentage (e.g., 25 means 25% off)
  discount: { type: Number, required: true },
  // Maximum number of users who can use this code (0 = unlimited)
  targetUsers: { type: Number, default: 0 },
  // How many users have already used this code
  usageCount: { type: Number, default: 0 },
  // List of user IDs who already used this code (prevents double usage)
  usedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  // Whether this code is currently active (admin can deactivate)
  isActive: { type: Boolean, default: true },
  // When this code was created
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('PromoCode', PromoCodeSchema);