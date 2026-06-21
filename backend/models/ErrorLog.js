// backend/models/ErrorLog.js
// ============================================================
// ERROR LOG MODEL — Stores all server errors and frontend crash reports.
// Every time an API error happens, the errorHandler middleware saves it here.
// The Flutter app can also report crashes via POST /api/admin/report-client-error.
// Admins see these in the dashboard and can mark them as resolved.
// ============================================================
const mongoose = require('mongoose');

const ErrorLogSchema = new mongoose.Schema({
  // Error code (e.g., 'BE-RES-001' for backend reservation error #1)
  // Format: BE = Backend, FE = Frontend, then module abbreviation + number
  errorCode: { type: String, required: true },
  // Human-readable error message
  message: { type: String, required: true },
  // Full stack trace (for debugging)
  stack: { type: String },
  // The API route that caused the error (e.g., '/api/reservation')
  path: { type: String },
  // HTTP method (GET, POST, PUT, etc.)
  method: { type: String },
  // Which user triggered the error (if authenticated)
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  // Extra context (request body, params, query string)
  metadata: { type: Object },
  // Whether an admin has reviewed and resolved this error
  isResolved: { type: Boolean, default: false },
  // When the error occurred
  createdAt: { type: Date, default: Date.now }
});

// --- Database Indexes ---
ErrorLogSchema.index({ errorCode: 1 });   // Search errors by code
ErrorLogSchema.index({ createdAt: -1 });   // Show newest errors first

module.exports = mongoose.model('ErrorLog', ErrorLogSchema);
