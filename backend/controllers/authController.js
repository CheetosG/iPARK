// backend/controllers/authController.js
// ============================================================
// AUTHENTICATION CONTROLLER — Handles user login, OTP verification,
// and new user registration. iPARK uses phone-based OTP login
// (no passwords). The flow is:
//   1. User enters phone → login() sends an OTP code
//   2. User enters the OTP → verify() checks it
//   3. If new user → register() creates their account
//   4. If existing user → verify() returns a JWT token
// ============================================================
const User = require('../models/User');
const { generateOTP, verifyOTP } = require('../utils/otpGenerator');
const jwt = require('jsonwebtoken');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// Secret key used to sign JWT tokens (from .env file)
const JWT_SECRET = process.env.JWT_SECRET;

// ----------------------------------------------------------
// STEP 1: LOGIN — Send OTP to the user's phone number
// POST /api/auth/login
// Body: { phoneNumber: "07XXXXXXXXX" }
// ----------------------------------------------------------
exports.login = catchAsync(async (req, res, next) => {
  const { phoneNumber } = req.body;
  if (!phoneNumber) {
    return next(new AppError('Phone number required', 400, 'BE-AUTH-001'));
  }

  // Remove spaces, dashes, parentheses from phone number
  const normalizedPhone = phoneNumber.replace(/[\s\-\(\)]/g, '');
  
  // Block banned users from even receiving an OTP
  const user = await User.findOne({ phoneNumber: normalizedPhone });
  if (user && user.isBanned) {
    return next(new AppError('Your account has been banned. Please contact support.', 403, 'BE-AUTH-003'));
  }

  // Generate a 6-digit OTP and store it in memory (see otpGenerator.js)
  // In production, this would be sent via SMS (e.g., Twilio)
  const otp = generateOTP(normalizedPhone);
  
  res.json({ success: true, message: 'OTP sent' });
});

// ----------------------------------------------------------
// STEP 2: VERIFY — Check if the entered OTP is correct
// POST /api/auth/verify
// Body: { phoneNumber: "07XXXXXXXXX", otp: "123456" }
// Returns: { isNew: true } for first-time users (need to register)
//          { user, token } for existing users (logged in!)
// ----------------------------------------------------------
exports.verify = catchAsync(async (req, res, next) => {
  const { phoneNumber, otp } = req.body;
  if (!phoneNumber || !otp) {
    return next(new AppError('Phone and OTP required', 400, 'BE-AUTH-002'));
  }

  const normalizedPhone = phoneNumber.replace(/[\s\-\(\)]/g, '');
  
  // Check the OTP against what was stored in memory
  if (verifyOTP(normalizedPhone, otp)) {
    // OTP is correct! Check if user already has an account
    let user = await User.findOne({ phoneNumber: normalizedPhone });
    
    if (!user) {
      // First-time user → tell the app to show the registration form
      res.json({ success: true, isNew: true, phoneNumber: normalizedPhone });
    } else {
      // Existing user → check ban status and issue a JWT token
      if (user.isBanned) {
        return next(new AppError('Your account has been banned.', 403, 'BE-AUTH-003'));
      }
      // JWT token is valid for 30 days
      const token = jwt.sign({ id: user._id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
      res.json({ success: true, isNew: false, user, token });
    }
  } else {
    // OTP is wrong or expired
    return next(new AppError('Invalid OTP', 400, 'BE-AUTH-004'));
  }
});

// ----------------------------------------------------------
// STEP 3: REGISTER — Create a new user account
// POST /api/auth/register
// Body: { phoneNumber, name, email, nationalId, carPlate }
// Called after a new user verifies their OTP successfully.
// Checks for duplicate phone/email/nationalId before creating.
// ----------------------------------------------------------
exports.register = catchAsync(async (req, res, next) => {
  const { phoneNumber, name, email, nationalId, carPlate } = req.body;
  
  if (!phoneNumber || !name || !email || !nationalId) {
    return next(new AppError('Name, Email, and National ID are required', 400, 'BE-AUTH-005'));
  }

  const normalizedPhone = phoneNumber.replace(/[\s\-\(\)]/g, '');

  // Check for duplicate phone number, email, or national ID
  const existingUser = await User.findOne({
    $or: [
      { phoneNumber: normalizedPhone },
      { email: email.toLowerCase() },
      { nationalId }
    ]
  });

  if (existingUser) {
    // Tell the user which field is already taken
    let conflictField = 'User';
    if (existingUser.phoneNumber === normalizedPhone) conflictField = 'Phone number';
    else if (existingUser.email === email.toLowerCase()) conflictField = 'Email';
    else if (existingUser.nationalId === nationalId) conflictField = 'National ID';
    
    return next(new AppError(`${conflictField} already registered`, 400, 'BE-AUTH-006'));
  }

  // Create the new user in MongoDB
  const user = await User.create({
    phoneNumber: normalizedPhone,
    name,
    email: email.toLowerCase(),
    nationalId,
    carPlate: carPlate || '',
    role: 'user',         // New users always start as regular users
    isVerified: true,      // They already verified via OTP
    points: 0              // Start with 0 reward points
  });

  // Issue a JWT token so the user is logged in immediately
  const token = jwt.sign({ id: user._id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

  res.json({ success: true, user, token });
});
