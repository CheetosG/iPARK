// backend/models/User.js
// ============================================================
// USER MODEL — Stores all registered user accounts in MongoDB.
// Each user has a phone number (for OTP login), personal info,
// a role (user/admin/support), reward points, and ban status.
// This is referenced by: Reservations, ChatMessages, PointHistory, etc.
// ============================================================
const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({

  // --- Authentication Fields ---
  // Phone number is the primary login method (OTP-based, no password)
  phoneNumber: { 
    type: String, 
    required: true, 
    unique: true,
    trim: true
  },

  // --- Personal Information ---
  name: { 
    type: String, 
    required: true,
    trim: true
  },
  email: { 
    type: String, 
    required: true, 
    unique: true,
    trim: true,
    lowercase: true  // Always stored in lowercase to avoid duplicates
  },
  // Iraqi National ID — used for identity verification
  nationalId: { 
    type: String, 
    required: true, 
    unique: true,
    trim: true
  },
  // Vehicle plate number — used during arrival verification & re-verification
  carPlate: { 
    type: String, 
    default: '',
    trim: true
  },

  // --- Role & Permissions ---
  // 'user' = normal user, 'admin' = full access, 'support' = can chat & manage users
  role: { 
    type: String, 
    default: 'user',
    enum: ['user', 'admin', 'support']
  },

  // --- Rewards System ---
  // Points earned from parking reservations (10 points per hour)
  points: { 
    type: Number, 
    default: 0 
  },
  // Profile picture URL (stored in uploads/profiles/ folder)
  photoUrl: { 
    type: String,
    default: ''
  },
  // If user redeemed points for a reward (e.g. '25% Discount'), it's stored here
  // and applied automatically on their next reservation, then cleared
  pendingReward: {
    type: String,
    default: null
  },

  // --- Account Status ---
  // Whether the user completed OTP verification
  isVerified: { 
    type: Boolean, 
    default: false 
  },
  // If true, user is blocked from logging in and all reservations are cancelled
  isBanned: {
    type: Boolean,
    default: false
  },

  // --- Timestamps ---
  createdAt: { 
    type: Date, 
    default: Date.now 
  }
});

module.exports = mongoose.model('User', UserSchema);