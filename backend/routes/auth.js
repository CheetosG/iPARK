// backend/routes/auth.js
// ============================================================
// AUTH ROUTES — Maps HTTP requests to the authController functions.
// No authentication required (these are public routes).
//
// Flow: User enters phone → gets OTP → verifies → registers (if new)
// ============================================================
const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// STEP 1: Send OTP to user's phone number
// POST /api/auth/login { phoneNumber }
router.post('/login', authController.login);

// STEP 2: Verify the OTP code entered by user
// POST /api/auth/verify { phoneNumber, otp }
router.post('/verify', authController.verify);

// STEP 3: Complete profile registration (for new users only)
// POST /api/auth/register { phoneNumber, name, email, nationalId, carPlate }
router.post('/register', authController.register);

module.exports = router;