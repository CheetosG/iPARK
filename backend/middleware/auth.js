// backend/middleware/auth.js
// ============================================================
// AUTHENTICATION MIDDLEWARE — Protects API routes from unauthorized access.
// Uses JWT (JSON Web Tokens) to verify user identity.
// Three middleware functions are exported:
//   1. authMiddleware — Verifies the JWT token and checks if user is banned
//   2. checkAdmin — Only allows users with role='admin'
//   3. checkSupportOrAdmin — Allows both 'admin' and 'support' roles
//
// Usage in routes:
//   router.get('/profile', authMiddleware, controller.getProfile);
//   router.get('/stats', authMiddleware, checkAdmin, controller.getStats);
// ============================================================
const jwt = require('jsonwebtoken');
const User = require('../models/User');

// ----------------------------------------------------------
// MIDDLEWARE 1: authMiddleware
// Extracts JWT from "Authorization: Bearer <token>" header,
// verifies it, loads the user from DB, checks ban status,
// and attaches the user object to req.user for route handlers.
// ----------------------------------------------------------
const authMiddleware = async (req, res, next) => {
  // Extract token from "Bearer <token>" format
  const token = req.headers.authorization?.split(' ')[1];

  // No token = not logged in
  if (!token) {
    return res.status(401).json({ success: false, message: 'No token provided, authorization denied' });
  }

  try {
    // Decode and verify the token using our secret key
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback_secret_key');
    
    // Load the full user from the database (to get latest role, ban status, etc.)
    const user = await User.findById(decoded.id);
    if (!user) {
      return res.status(401).json({ success: false, message: 'User no longer exists' });
    }

    // Block banned users from making any API requests
    if (user.isBanned) {
      return res.status(403).json({ 
        success: false, 
        message: 'Your account has been banned. Please contact support.',
        isBanned: true 
      });
    }

    // Attach user to request — available in all route handlers as req.user
    req.user = user; 
    next();
  } catch (error) {
    // Token is expired or tampered with
    res.status(401).json({ success: false, message: 'Token is not valid' });
  }
};

// ----------------------------------------------------------
// MIDDLEWARE 2: checkAdmin
// Must be used AFTER authMiddleware. Blocks non-admin users.
// ----------------------------------------------------------
const checkAdmin = (req, res, next) => {
  if (req.user && req.user.role === 'admin') {
    next();
  } else {
    res.status(403).json({ success: false, message: 'Access Denied: Admin only' });
  }
};

// ----------------------------------------------------------
// MIDDLEWARE 3: checkSupportOrAdmin
// Must be used AFTER authMiddleware. Allows admin OR support staff.
// Used for routes like user management, chat, and ticket resolution.
// ----------------------------------------------------------
const checkSupportOrAdmin = (req, res, next) => {
  if (req.user && (req.user.role === 'admin' || req.user.role === 'support')) {
    next();
  } else {
    res.status(403).json({ success: false, message: 'Access Denied: Staff only' });
  }
};

module.exports = { authMiddleware, checkAdmin, checkSupportOrAdmin };
