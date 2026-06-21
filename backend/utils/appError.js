// backend/utils/appError.js
// ============================================================
// CUSTOM ERROR CLASS — Used to throw meaningful errors in route handlers.
// Instead of: throw new Error("Bad request")
// We use:     throw new AppError("Spot not found", 404, "BE-RES-002")
//
// This gives us:
//   - A human-readable message for the user
//   - An HTTP status code (400, 404, 500, etc.)
//   - A unique error code for tracking (e.g., BE-RES-002)
//   - A flag to distinguish our errors from unexpected crashes
// ============================================================
class AppError extends Error {
  constructor(message, statusCode, errorCode = 'BE-GEN-001') {
    super(message);
    this.statusCode = statusCode;           // HTTP status (400, 404, 500)
    this.errorCode = errorCode;             // Custom tracking code
    this.status = `${statusCode}`.startsWith('4') ? 'fail' : 'error';  // 4xx = fail, 5xx = error
    this.isOperational = true;              // true = expected error (not a bug)

    // Removes this constructor from the stack trace for cleaner debugging
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
