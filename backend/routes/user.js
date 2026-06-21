// backend/routes/user.js
// ============================================================
// USER ROUTES — Routes for user profile, points, and support.
// All routes require authentication (authMiddleware).
// Used by the Profile, Rewards, and Contact Support screens.
// ============================================================
const express = require('express');
const router = require('express').Router();
const userController = require('../controllers/userController');
const { authMiddleware } = require('../middleware/auth');
const upload = require('../middleware/multer');

// Get the logged-in user's profile data
// GET /api/user/profile
router.get('/profile', authMiddleware, userController.getProfile);

// Update profile fields (name, email, car plate, etc.)
// PUT /api/user/profile { name, email, carPlate, ... }
router.put('/profile', authMiddleware, userController.updateProfile);

// Upload a new profile photo (replaces old one)
// POST /api/user/profile-photo [multipart: photo file]
router.post('/profile-photo', authMiddleware, upload.single('photo'), userController.uploadProfilePhoto);

// Get the user's last 10 point transactions
// GET /api/user/points/history
router.get('/points/history', authMiddleware, userController.getPointHistory);

// Redeem points for a reward (e.g., 500 points → 25% discount)
// POST /api/user/points/exchange { amount: 500, reason: "25% Discount" }
router.post('/points/exchange', authMiddleware, userController.exchangePoints);

// Submit a new support ticket
// POST /api/user/support { subject, message }
router.post('/support', authMiddleware, userController.submitTicket);

// Get all tickets submitted by the current user
// GET /api/user/support
router.get('/support', authMiddleware, userController.getMyTickets);

module.exports = router;