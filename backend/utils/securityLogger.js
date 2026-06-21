// backend/utils/securityLogger.js
const fs = require('fs');
const path = require('path');
const ErrorLog = require('../models/ErrorLog');

const LOG_FILE_PATH = path.join(__dirname, '..', 'security_audit.log');

/**
 * Logs a security event to both the MongoDB ErrorLog collection and an append-only text file.
 * 
 * @param {Object} eventData
 * @param {string} eventData.errorCode - Unique security error code (e.g., 'BE-SEC-UNAUTHORIZED')
 * @param {string} eventData.message - Descriptive alert message
 * @param {string} [eventData.path] - Requested API route path
 * @param {string} [eventData.method] - Requested HTTP method (GET, PUT, etc.)
 * @param {string} [eventData.userId] - ID of the user if authenticated
 * @param {Object} [eventData.metadata] - Extra context (IP, request body, headers, etc.)
 * @param {Object} [app] - Express application instance to broadcast socket notifications
 */
exports.logSecurityEvent = async (eventData, app = null) => {
  const timestamp = new Date();
  const logMessage = `[${timestamp.toISOString()}] [${eventData.errorCode}] ${eventData.method || 'N/A'} ${eventData.path || 'N/A'} - User: ${eventData.userId || 'Anonymous'} - Message: ${eventData.message} - Metadata: ${JSON.stringify(eventData.metadata || {})}\n`;

  // 1. Append to server security_audit.log (Immutable Log File)
  try {
    fs.appendFileSync(LOG_FILE_PATH, logMessage);
  } catch (fileErr) {
    console.error('CRITICAL: Failed to append to security_audit.log:', fileErr.message);
  }

  // 2. Save to database ErrorLog collection for admin notification & visibility
  try {
    const log = await ErrorLog.create({
      errorCode: eventData.errorCode,
      message: eventData.message,
      path: eventData.path || 'SecurityModule',
      method: eventData.method || 'SYSTEM',
      userId: eventData.userId || null,
      metadata: eventData.metadata || {},
      createdAt: timestamp
    });

    // 3. Emit real-time Socket.io alert to Admins
    if (app) {
      const io = app.get('io');
      if (io) {
        io.emit('system_error_alert', {
          logId: log._id,
          errorCode: eventData.errorCode,
          message: eventData.message,
          path: eventData.path || 'SecurityModule',
          timestamp
        });
      }
    }
  } catch (dbErr) {
    console.error('CRITICAL: Failed to save security log to MongoDB:', dbErr.message);
  }
};
