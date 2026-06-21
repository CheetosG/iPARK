// backend/middleware/deviceAuth.js
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { logSecurityEvent } = require('../utils/securityLogger');

/**
 * Middleware that secures endpoints by requiring either a valid ESP32 API Key
 * or a valid Admin JWT token. Integrates with immutable logging and failsafe systems.
 */
module.exports = async (req, res, next) => {
  const apiKey = req.headers['x-api-key'];

  // Case 1: Device authentication attempt via API Key
  if (apiKey !== undefined) {
    const configuredApiKey = process.env.ESP32_API_KEY;

    if (!configuredApiKey) {
      console.warn('WARNING: ESP32_API_KEY is not configured in environment variables.');
    }

    if (apiKey === configuredApiKey && configuredApiKey) {
      req.isDevice = true;
      return next();
    }

    // Invalid API Key - log security event (failsafe check)
    await logSecurityEvent({
      errorCode: 'BE-SEC-UNAUTHORIZED',
      message: `Security Failsafe Triggered: Invalid API Key attempt from IP: ${req.ip}`,
      path: req.originalUrl,
      method: req.method,
      metadata: {
        providedKey: apiKey,
        ip: req.ip,
        headers: req.headers,
        body: req.body
      }
    }, req.app);

    return res.status(401).json({
      success: false,
      errorCode: 'BE-SEC-UNAUTHORIZED',
      message: 'Access Denied: Invalid API Key provided'
    });
  }

  // Case 2: Standard user auth fallback via JWT Token (For Admins using Frontend)
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1];

  if (!token) {
    // Missing credentials entirely
    await logSecurityEvent({
      errorCode: 'BE-SEC-UNAUTHORIZED',
      message: `Security Failsafe Triggered: Unauthorized access attempt to device endpoint from IP: ${req.ip}`,
      path: req.originalUrl,
      method: req.method,
      metadata: { ip: req.ip, headers: req.headers }
    }, req.app);

    return res.status(401).json({
      success: false,
      errorCode: 'BE-SEC-UNAUTHORIZED',
      message: 'Access Denied: No API key or authorization token provided'
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'fallback_secret_key');
    const user = await User.findById(decoded.id);

    if (!user) {
      return res.status(401).json({ success: false, message: 'User no longer exists' });
    }

    if (user.isBanned) {
      return res.status(403).json({ success: false, message: 'User account is banned' });
    }

    if (user.role !== 'admin') {
      // Log privilege escalation attempt
      await logSecurityEvent({
        errorCode: 'BE-SEC-PRIVILEGE',
        message: `Elevation of Privilege Blocked: Non-admin user (${user.name}) tried to perform device operation.`,
        path: req.originalUrl,
        method: req.method,
        userId: user._id,
        metadata: {
          ip: req.ip,
          role: user.role,
          name: user.name,
          email: user.email
        }
      }, req.app);

      return res.status(403).json({
        success: false,
        errorCode: 'BE-SEC-PRIVILEGE',
        message: 'Access Denied: Admin authorization required'
      });
    }

    req.user = user;
    req.isDevice = false;
    next();
  } catch (error) {
    // Log invalid token attempt
    await logSecurityEvent({
      errorCode: 'BE-SEC-UNAUTHORIZED',
      message: `Security Failsafe Triggered: Invalid JWT token provided to device endpoint.`,
      path: req.originalUrl,
      method: req.method,
      metadata: { error: error.message, ip: req.ip }
    }, req.app);

    return res.status(401).json({
      success: false,
      errorCode: 'BE-SEC-UNAUTHORIZED',
      message: 'Access Denied: Token is not valid'
    });
  }
};
