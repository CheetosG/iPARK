// backend/middleware/errorHandler.js
// ============================================================
// GLOBAL ERROR HANDLER — The last middleware in the Express chain.
// Every error thrown in any route handler ends up here.
// It does 3 things:
//   1. Saves the error to the ErrorLog collection in MongoDB
//   2. Notifies admins in real-time via Socket.IO (system_error_alert)
//   3. Sends a clean JSON error response to the client
// ============================================================
const ErrorLog = require('../models/ErrorLog');

module.exports = async (err, req, res, next) => {
    // Set defaults for missing error properties
    err.statusCode = err.statusCode || 500;
    err.status = err.status || 'error';
    err.errorCode = err.errorCode || 'BE-GEN-500';

    // --- STEP 1: Save error to database for admin review ---
    try {
        const errorData = {
            errorCode: err.errorCode,
            message: err.message,
            stack: err.stack,
            path: req.originalUrl,       // Which API route failed
            method: req.method,          // GET, POST, PUT, etc.
            userId: req.user ? req.user.id : null,  // Who triggered it
            metadata: {
                body: req.body,          // Request body (for debugging)
                params: req.params,      // URL parameters
                query: req.query         // Query string parameters
            }
        };
        const log = await ErrorLog.create(errorData);

        // --- STEP 2: Notify admins in real-time via Socket.IO ---
        const io = req.app.get('io');
        if (io) {
            io.emit('system_error_alert', {
                logId: log._id,
                errorCode: err.errorCode,
                message: err.message,
                path: req.originalUrl,
                timestamp: new Date()
            });
        }
    } catch (logLogErr) {
        // If we can't even log the error, print it to console
        console.error('CRITICAL: Failed to log error to DB:', logLogErr.message);
    }

    // --- STEP 3: Print to server console for developer debugging ---
    console.error(`[${err.errorCode}] ERROR ${req.method} ${req.originalUrl}:`, err.message);
    if (process.env.NODE_ENV === 'development') {
        console.error(err.stack);  // Show full stack trace only in development
    }

    // --- STEP 4: Send JSON error response to the Flutter app ---
    res.status(err.statusCode).json({
        success: false,
        status: err.status,
        errorCode: err.errorCode,
        message: err.message,
        // Only include stack trace in development (security: don't expose in production)
        stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
    });
};
