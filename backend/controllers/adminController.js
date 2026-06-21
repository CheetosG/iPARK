// backend/controllers/adminController.js
// ============================================================
// ADMIN CONTROLLER — Powers the admin dashboard and staff management.
// Only accessible by users with role='admin' or role='support'.
//
// ENDPOINTS:
//   GET  /api/admin/stats              → getStats (dashboard numbers)
//   POST /api/admin/add-mall           → addMall (create new mall + spots)
//   PATCH /api/admin/mall/:id          → updateMall (edit mall details)
//   POST /api/admin/add-support        → addSupport (promote user to support)
//   POST /api/admin/create-promo       → createPromoCode
//   GET  /api/admin/messages           → getMessages (support tickets)
//   GET  /api/admin/users              → getUsers (all users list)
//   GET  /api/admin/users/:id          → getUser (single user detail)
//   GET  /api/admin/users/:id/history  → getUserHistory (user's reservations)
//   PATCH /api/admin/users/:id/ban     → toggleBan (ban/unban user)
//   PATCH /api/admin/users/:id/role    → updateRole (change user role)
//   PATCH /api/admin/messages/:id      → resolveTicket (mark ticket as solved)
// ============================================================
const User = require('../models/User');
const SupportTicket = require('../models/SupportTicket');
const Spot = require('../models/Spot');
const Reservation = require('../models/Reservation');
const PromoCode = require('../models/PromoCode');
const Mall = require('../models/Mall');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// ----------------------------------------------------------
// GET STATS — Dashboard overview numbers
// Returns: total users, reservations, malls, promo codes, total revenue
// Shown on the admin dashboard screen.
// ----------------------------------------------------------
exports.getStats = catchAsync(async (req, res, next) => {
  const totalUsers = await User.countDocuments();
  const totalReservations = await Reservation.countDocuments();
  const totalMalls = await Mall.countDocuments();
  const totalPromos = await PromoCode.countDocuments();
  // Calculate total revenue from all reservations using MongoDB aggregation
  const profitResult = await Reservation.aggregate([
    { $group: { _id: null, total: { $sum: '$amount' } } }
  ]);
  res.json({ 
    totalUsers, 
    totalReservations, 
    totalMalls, 
    totalPromos, 
    profit: profitResult[0]?.total || 0 
  });
});

// ----------------------------------------------------------
// ADD MALL — Create a new parking location
// Body: { name, location, address, totalSpots, description, pricePerHour }
// File: mallPhoto (optional, uploaded via multer middleware)
//
// Also auto-creates all parking spots (A-1, A-2, ... A-N)
// and emits a real-time 'mall_added' event to all clients.
// ----------------------------------------------------------
exports.addMall = catchAsync(async (req, res, next) => {
  req.body = req.body || {};
  const { name, location, address, photoUrl, totalSpots, description, pricePerHour } = req.body;
  if (!name || !totalSpots) {
    return next(new AppError('Name and Total Spots are required', 400, 'BE-ADM-001'));
  }

  // Build mall data object
  const mallData = { 
    name, 
    location, 
    address, 
    totalSpots, 
    description, 
    pricePerHour 
  };

  // Handle photo: prefer uploaded file, fall back to URL
  if (req.file) {
    mallData.photoUrl = req.file.path.replace(/\\/g, '/');
  } else if (photoUrl) {
    mallData.photoUrl = photoUrl;
  }

  // Create the mall in MongoDB
  const mall = await Mall.create(mallData);
  
  // Auto-generate parking spots (A-1, A-2, ... A-N) with green status
  const spots = [];
  for (let i = 1; i <= totalSpots; i++) {
    spots.push({
      mallId: mall._id,
      spotNumber: `A-${i}`, 
      status: 'green'       // All new spots start as available
    });
  }
  await Spot.insertMany(spots);
  
  // Notify all connected Flutter apps that a new mall was added
  const io = req.app.get('io');
  if (io) {
    io.emit('mall_added', mall);
    console.log(`[SOCKET] Emitted mall_added: ${mall.name}`);
  }
  
  res.json({ success: true, mall });
});

// ----------------------------------------------------------
// UPDATE MALL — Edit an existing mall's details
// PATCH /api/admin/mall/:id
// Body: { name, location, description, pricePerHour, totalSpots }
//
// If totalSpots is INCREASED, new spots are auto-created.
// If totalSpots is DECREASED, excess spots are deleted
// (but only if they're not currently reserved).
// ----------------------------------------------------------
exports.updateMall = catchAsync(async (req, res, next) => {
  req.body = req.body || {};
  const { name, location, description, pricePerHour, photoUrl, totalSpots } = req.body;
  const mall = await Mall.findById(req.params.id);
  if (!mall) {
    return next(new AppError('Mall not found', 404, 'BE-ADM-002'));
  }

  const oldTotal = mall.totalSpots || 0;
  const newTotal = parseInt(totalSpots);

  // --- Handle spot count changes ---
  if (newTotal > oldTotal) {
    // ADDING spots: create new ones (A-oldTotal+1 ... A-newTotal)
    const spotsToAdd = [];
    for (let i = oldTotal + 1; i <= newTotal; i++) {
      spotsToAdd.push({
        mallId: mall._id,
        spotNumber: `A-${i}`,
        status: 'green'
      });
    }
    await Spot.insertMany(spotsToAdd);
  } else if (newTotal < oldTotal) {
    // REMOVING spots: check none are currently reserved
    const spotsToRemove = await Spot.find({ mallId: mall._id }).lean();
    const reservedSpots = spotsToRemove.filter(s => {
      const numSuffix = s.spotNumber.split('-')[1];
      const num = parseInt(numSuffix);
      return num > newTotal && (s.status === 'red' || s.status === 'yellow');
    });

    // Block deletion if any spots-to-remove are occupied
    if (reservedSpots.length > 0) {
      return next(new AppError(`Cannot decrease spots: Some spots to be removed (e.g. ${reservedSpots[0].spotNumber}) are currently reserved.`, 400, 'BE-ADM-003'));
    }

    // Safe to delete excess spots
    for (let i = oldTotal; i > newTotal; i--) {
      await Spot.findOneAndDelete({ mallId: mall._id, spotNumber: `A-${i}` });
    }
  }

  // Update mall fields
  mall.name = name || mall.name;
  mall.location = location || mall.location;
  mall.description = description || mall.description;
  mall.pricePerHour = pricePerHour !== undefined ? pricePerHour : mall.pricePerHour;
  
  // Handle photo update
  if (req.file) {
    mall.photoUrl = req.file.path.replace(/\\/g, '/');
  } else if (photoUrl) {
    mall.photoUrl = photoUrl;
  }
  mall.totalSpots = newTotal;

  await mall.save();

  // Notify all connected clients that mall info was updated
  const io = req.app.get('io');
  if (io) {
    io.emit('mall_updated', mall);
    console.log(`[SOCKET] Emitted mall_updated: ${mall.name}`);
  }

  res.json({ success: true, mall });
});

// ----------------------------------------------------------
// ADD SUPPORT — Promote a user to support staff role
// POST /api/admin/add-support
// Body: { phoneNumber: "07XXXXXXXXX" }
// Cannot promote an admin to support (downgrade not allowed).
// Emits real-time 'role_updated' event to the user's device.
// ----------------------------------------------------------
exports.addSupport = catchAsync(async (req, res, next) => {
  const { phoneNumber } = req.body;
  if (!phoneNumber) return next(new AppError('Phone number required', 400, 'BE-ADM-005'));

  // Prevent demoting an admin
  const user = await User.findOne({ phoneNumber });
  if (user && user.role === 'admin') {
    return next(new AppError('Cannot demote an admin to support', 400, 'BE-ADM-015'));
  }

  const updatedUser = await User.findOneAndUpdate(
    { phoneNumber }, 
    { role: 'support' }, 
    { upsert: true, new: true }
  );

  // Notify the user's app immediately so the UI changes
  const io = req.app.get('io');
  if (io && updatedUser) {
    io.to(updatedUser._id.toString()).emit('role_updated', { role: 'support' });
    console.log(`[SOCKET] Emitted role_updated to user ${updatedUser._id}: support`);
  }

  res.json({ success: true, message: 'Support Member Added' });
});

// ----------------------------------------------------------
// CREATE PROMO CODE — Add a new discount code
// POST /api/admin/create-promo
// Body: { code: "SUMMER25", discount: 25, targetUsers: 100 }
// ----------------------------------------------------------
exports.createPromoCode = catchAsync(async (req, res, next) => {
  const { code, discount, targetUsers } = req.body;
  if (!code || !discount) {
    return next(new AppError('Code and Discount are required', 400, 'BE-ADM-006'));
  }
  const promo = await PromoCode.create({ code, discount, targetUsers });
  res.json({ success: true, promo });
});

// ----------------------------------------------------------
// GET MESSAGES — List all support tickets
// GET /api/admin/messages
// Returns tickets with user name and phone number.
// Accessible by both admin and support staff.
// ----------------------------------------------------------
exports.getMessages = catchAsync(async (req, res, next) => {
  const messages = await SupportTicket.find().populate('userId', 'name phoneNumber').sort({ createdAt: -1 });
  res.json({ success: true, messages });
});

// ----------------------------------------------------------
// RESOLVE TICKET — Mark a support ticket as solved
// PATCH /api/admin/messages/:id
// Body: { response: "Your issue has been resolved..." }
// ----------------------------------------------------------
exports.resolveTicket = catchAsync(async (req, res, next) => {
  const { response } = req.body;
  const ticket = await SupportTicket.findByIdAndUpdate(req.params.id, { 
    status: 'solved',
    adminResponse: response,
    respondedAt: new Date()
  }, { new: true });
  
  if (!ticket) {
    return next(new AppError('Ticket not found', 404, 'BE-ADM-004'));
  }
  res.json({ success: true, ticket });
});

// ----------------------------------------------------------
// GET USERS — List all users in the system
// GET /api/admin/users
// Support staff cannot see admin accounts (security).
// ----------------------------------------------------------
exports.getUsers = catchAsync(async (req, res, next) => {
  let query = User.find().select('-otp -otpExpires');
  
  // Hide admins from support staff view
  if (req.user.role === 'support') {
    query = query.find({ role: { $ne: 'admin' } });
  }

  const users = await query.sort({ createdAt: -1 });
  res.json({ success: true, users });
});

// ----------------------------------------------------------
// GET USER — Get a single user's details
// GET /api/admin/users/:id
// ----------------------------------------------------------
exports.getUser = catchAsync(async (req, res, next) => {
  const user = await User.findById(req.params.id).select('-otp -otpExpires');
  if (!user) return next(new AppError('User not found', 404, 'BE-ADM-011'));
  res.json({ success: true, user });
});

// ----------------------------------------------------------
// GET USER HISTORY — Get all reservations for a specific user
// GET /api/admin/users/:id/history
// Used in the user detail screen to view booking history.
// ----------------------------------------------------------
exports.getUserHistory = catchAsync(async (req, res, next) => {
  const reservations = await Reservation.find({ userId: req.params.id })
    .populate('mallId', 'name location')
    .populate('spotId', 'spotNumber')
    .sort({ createdAt: -1 });
  res.json({ success: true, reservations });
});

// ----------------------------------------------------------
// TOGGLE BAN — Ban or unban a user
// PATCH /api/admin/users/:id/ban
// When banning:
//   1. Sends 'user_banned' event to kick them out of the app
//   2. Cancels ALL their active/pending reservations
// When unbanning: Just sets isBanned = false
// Admins cannot be banned. Support cannot ban other support.
// ----------------------------------------------------------
exports.toggleBan = catchAsync(async (req, res, next) => {
  const user = await User.findById(req.params.id);
  if (!user) return next(new AppError('User not found', 404, 'BE-ADM-007'));
  
  // Safety: prevent banning admin accounts
  if (user.role === 'admin') {
    return next(new AppError('Cannot ban an admin account', 403, 'BE-ADM-008'));
  }

  // Support staff cannot ban other support staff
  if (req.user.role === 'support' && user.role === 'support') {
    return next(new AppError('Supporters cannot ban other staff members', 403, 'BE-ADM-012'));
  }

  // Toggle the ban status
  user.isBanned = !user.isBanned;
  await user.save();

  // If the user was just BANNED, take immediate action
  if (user.isBanned) {
    // Send real-time kick notification to the user's app
    const io = req.app.get('io');
    if (io) {
      console.log(`[BAN] Emitting user_banned to room ${user._id}`);
      io.to(user._id.toString()).emit('user_banned', { userId: user._id, message: 'Your account has been banned' });
    }

    // Cancel all their active reservations (free up their spots)
    await Reservation.updateMany(
      { userId: user._id, status: { $in: ['pending', 'active'] } },
      { status: 'cancelled' }
    );
    console.log(`[BAN] Cancelled active reservations for User ${user._id}`);
  }

  res.json({ success: true, isBanned: user.isBanned });
});

// ----------------------------------------------------------
// UPDATE ROLE — Change a user's role (user/support)
// PATCH /api/admin/users/:id/role
// Body: { role: "support" | "user" }
// Cannot change an admin's role. Emits 'role_updated' event.
// ----------------------------------------------------------
exports.updateRole = catchAsync(async (req, res, next) => {
  const { role } = req.body;
  const user = await User.findById(req.params.id);
  if (!user) return next(new AppError('User not found', 404, 'BE-ADM-009'));
  
  if (user.role === 'admin') {
    return next(new AppError('Cannot change admin role', 400, 'BE-ADM-010'));
  }

  user.role = role;
  await user.save();

  // Notify the user's app immediately so the UI updates
  const io = req.app.get('io');
  if (io) {
    io.to(user._id.toString()).emit('role_updated', { role: user.role });
    console.log(`[SOCKET] Emitted role_updated to user ${user._id}: ${user.role}`);
  }

  res.json({ success: true, role: user.role });
});
