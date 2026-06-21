// backend/controllers/userController.js
// ============================================================
// USER CONTROLLER — Handles user profile, points, and support tickets.
// These endpoints are used by the Profile, Rewards, and Support screens.
// All routes require authentication (authMiddleware).
// ============================================================
const User = require('../models/User');
const PointHistory = require('../models/PointHistory');
const SupportTicket = require('../models/SupportTicket');
const fs = require('fs');
const path = require('path');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// ----------------------------------------------------------
// GET PROFILE
// GET /api/user/profile
// Returns the current user's full profile data.
// Used when the app loads to populate the profile screen.
// ----------------------------------------------------------
exports.getProfile = catchAsync(async (req, res, next) => {
  // req.user is set by authMiddleware (contains the logged-in user)
  const user = await User.findById(req.user.id).select('-otp -otpExpires');
  if (!user) return next(new AppError('User not found', 404, 'BE-USR-001'));
  res.json({ success: true, user });
});

// ----------------------------------------------------------
// UPDATE PROFILE
// PUT /api/user/profile
// Body: { name, email, carPlate, ... }
// Updates any fields the user changed in the profile edit screen.
// ----------------------------------------------------------
exports.updateProfile = catchAsync(async (req, res, next) => {
  const updates = req.body;
  const user = await User.findByIdAndUpdate(req.user.id, updates, { new: true });
  res.json({ success: true, user });
});

// ----------------------------------------------------------
// UPLOAD PROFILE PHOTO
// POST /api/user/profile-photo
// Multipart form with file field "photo"
// Saves the image to uploads/profiles/ and updates the user record.
// Also deletes the old photo if it exists (prevents accumulation).
// ----------------------------------------------------------
exports.uploadProfilePhoto = catchAsync(async (req, res, next) => {
  if (!req.file) {
      return next(new AppError('No file uploaded', 400, 'BE-USR-004'));
  }

  const user = await User.findById(req.user.id);
  if (!user) return next(new AppError('User not found', 404, 'BE-USR-001'));

  // Delete the old profile photo from disk (if it exists)
  if (user.photoUrl && user.photoUrl.startsWith('uploads/')) {
      const oldPath = path.join(__dirname, '..', user.photoUrl);
      if (fs.existsSync(oldPath)) {
          fs.unlinkSync(oldPath);
      }
  }

  // Save the new photo path in the database
  // Multer stores it in uploads/profiles/filename
  const photoUrl = `uploads/profiles/${req.file.filename}`;
  
  user.photoUrl = photoUrl;
  await user.save();

  res.json({
      success: true,
      photoUrl: photoUrl,
      message: 'Profile photo updated successfully'
  });
});

// ----------------------------------------------------------
// GET POINT HISTORY
// GET /api/user/points/history
// Returns the last 10 point transactions (earned/redeemed).
// Shown on the Rewards screen.
// ----------------------------------------------------------
exports.getPointHistory = catchAsync(async (req, res, next) => {
  const history = await PointHistory.find({ userId: req.user.id }).sort({ createdAt: -1 }).limit(10);
  res.json({ success: true, history });
});

// ----------------------------------------------------------
// EXCHANGE POINTS (Redeem a reward)
// POST /api/user/points/exchange
// Body: { amount: 500, reason: "25% Discount" }
// Deducts points from user and sets a "pending reward" that
// is automatically applied to their next reservation.
// ----------------------------------------------------------
exports.exchangePoints = catchAsync(async (req, res, next) => {
    const { amount, reason } = req.body;
    const user = await User.findById(req.user.id);
    
    // Make sure user has enough points
    if (user.points < amount) {
      return next(new AppError('Insufficient points', 400, 'BE-USR-002'));
    }

    // Deduct points and set the pending reward
    user.points -= amount;
    user.pendingReward = reason;  // e.g., "25% Discount" — applied on next booking
    await user.save();

    // Record the transaction in point history
    await PointHistory.create({
      userId: req.user.id,
      amount: -amount,                  // Negative = points spent
      reason: `Redeemed: ${reason}`,
      createdAt: new Date()
    });

    res.json({ success: true, newPoints: user.points });
});

// ----------------------------------------------------------
// SUBMIT SUPPORT TICKET
// POST /api/user/support
// Body: { subject: "Payment issue", message: "I was double charged..." }
// Creates a support ticket that admin/staff can view and respond to.
// Also emits a real-time notification to the admin dashboard.
// ----------------------------------------------------------
exports.submitTicket = catchAsync(async (req, res, next) => {
    const { subject, message } = req.body;
    if (!subject || !message) {
      return next(new AppError('Subject and message are required', 400, 'BE-USR-003'));
    }

    const ticket = await SupportTicket.create({
      userId: req.user.id,
      subject,
      message,
      status: 'open'
    });

    // Notify admin dashboard in real-time
    const io = req.app.get('io');
    if (io) {
      io.emit('new_ticket', { id: ticket._id, subject: ticket.subject, userName: req.user.name || 'A user' });

      // --- ADMIN / SUPPORT PUSH NOTIFICATIONS ---
      const staffUsers = await User.find({ role: { $in: ['admin', 'support'] } });
      staffUsers.forEach(staff => {
        io.to(staff._id.toString()).emit('admin_support_alert', {
          type: 'ticket',
          title: 'New Support Ticket',
          body: `${req.user.name || 'A user'} submitted a request: ${subject}`,
          data: ticket
        });
      });
    }

    res.json({ success: true, ticket });
});

// ----------------------------------------------------------
// GET MY TICKETS
// GET /api/user/support
// Returns all support tickets submitted by the current user.
// Shown in the Contact Support screen.
// ----------------------------------------------------------
exports.getMyTickets = catchAsync(async (req, res, next) => {
  const tickets = await SupportTicket.find({ userId: req.user.id }).sort({ createdAt: -1 });
  res.json({ success: true, tickets });
});
