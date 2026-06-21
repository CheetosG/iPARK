// backend/models/SupportTicket.js
// ============================================================
// SUPPORT TICKET MODEL — Stores support requests submitted by users.
// Users create tickets from the Contact Support screen.
// Admin/support staff can view and resolve tickets from the dashboard.
// Different from ChatMessages — tickets are one-time forms, not real-time chat.
// ============================================================
const mongoose = require('mongoose');

const SupportTicketSchema = new mongoose.Schema({
  // Which user submitted this ticket
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  // Brief topic of the issue (e.g., "Payment Problem")
  subject: {
    type: String,
    required: true,
    trim: true
  },
  // Detailed description of the user's issue
  message: {
    type: String,
    required: true,
    trim: true
  },
  // Current state: 'open' = waiting for response, 'solved' = admin responded
  status: {
    type: String,
    enum: ['open', 'solved'],
    default: 'open'
  },
  // Admin/support staff's response message
  adminResponse: {
    type: String,
    trim: true
  },
  // When the admin responded to this ticket
  respondedAt: {
    type: Date
  },
  // When the user submitted this ticket
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('SupportTicket', SupportTicketSchema);
