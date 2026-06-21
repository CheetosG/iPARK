// backend/controllers/reservationController.js
// ============================================================
// RESERVATION CONTROLLER — The core business logic of iPARK.
// Handles creating, viewing, cancelling, and managing reservations.
// Also handles the leave-early detection and plate re-verification flow.
//
// ENDPOINTS:
//   POST   /api/reservation           → createReservation (book a spot)
//   GET    /api/reservation/activity   → getMyActivity (user's bookings)
//   DELETE /api/reservation/:id        → cancelReservation
//   PUT    /api/reservation/:id/status → updateReservationStatus (verify arrival)
//   POST   /api/reservation/validate-promo → validatePromoCode
//   PUT    /api/reservation/:id/leave-early → handleLeaveEarlyResponse
//   PUT    /api/reservation/:id/reverify    → reverifyPlate
// ============================================================
const Reservation = require('../models/Reservation');
const Spot = require('../models/Spot');
const User = require('../models/User');
const PointHistory = require('../models/PointHistory');
const Mall = require('../models/Mall');
const PromoCode = require('../models/PromoCode');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// Helper: normalizes status strings to lowercase for comparison
const normalize = (s) => (s || '').toLowerCase();

// ----------------------------------------------------------
// CREATE RESERVATION — Book a parking spot
// POST /api/reservation
// Body: { spotId, mallId, carPlate, startTime, endTime, promoCode? }
//
// This is the most complex endpoint. It does:
// 1. Validates the spot is available and not disabled
// 2. Calculates price (hours × pricePerHour)
// 3. Applies pending rewards (25%/50%/100% discount from points exchange)
// 4. Applies promo code discount (if provided)
// 5. Checks for time overlaps (same spot AND same user)
// 6. Creates the reservation, awards points, updates spot status
// 7. If anything fails, rolls back ALL changes (transaction-like)
// ----------------------------------------------------------
exports.createReservation = catchAsync(async (req, res, next) => {
  let createdReservationId = null;
  let spotToRevert = null;
  let hasAppliedReward = false;
  let rewardToClear = null;
  let pointsAddedToUser = false;
  let pointsToRevert = 0;

  const { spotId, mallId, carPlate, startTime, endTime, promoCode } = req.body;
  const userId = req.user ? req.user.id : null; 
  
  try {
    if (!userId || !spotId || !mallId) {
      throw new AppError('Missing required fields.', 400, 'BE-RES-001');
    }

    const spot = await Spot.findById(spotId);
    if (!spot) throw new AppError('Spot not found.', 404, 'BE-RES-002');
    
    if (spot.status === 'disabled') {
      throw new AppError('This spot is currently disabled and unavailable for reservation.', 400, 'BE-RES-014');
    }

    spotToRevert = spotId;

    const mall = await Mall.findById(mallId);
    if (!mall) throw new AppError('Mall not found.', 404, 'BE-RES-003');

    const start = new Date(startTime);
    const end = new Date(endTime);
    const now = new Date();

    console.log(`[RESERVATION ATTEMPT] Start: ${start.toISOString()}, Now: ${now.toISOString()}, End: ${end.toISOString()}`);

    // 1. Prevent past reservations (allow 2 min grace for network lag)
    if (start < new Date(now.getTime() - 2 * 60 * 1000)) {
      console.log(`[RESERVATION BLOCKED] Start time ${start.toISOString()} is in the past compared to ${now.toISOString()}`);
      throw new AppError('Cannot create a reservation for a time that has already passed.', 400, 'BE-RES-015');
    }

    const durationMinutes = Math.round((end - start) / (1000 * 60));
    if (durationMinutes <= 0) throw new AppError('Leaving time must be after arrival time.', 400, 'BE-RES-004');

    const hours = Math.max(1, Math.ceil(durationMinutes / 60));
    const pointsEarned = Math.max(1, Math.round((durationMinutes / 60) * 10));
    const pricePerHour = (mall.pricePerHour && mall.pricePerHour > 0) ? mall.pricePerHour : 20;
    let amount = hours * pricePerHour;

    const user = await User.findById(userId);
    if (user && user.pendingReward) {
      const rewardDiscounts = { '25% Discount': 25, '50% Discount': 50, 'Free Parking': 100 };
      const rewardPerc = rewardDiscounts[user.pendingReward] || 0;
      if (rewardPerc > 0) {
        amount -= (amount * rewardPerc) / 100;
        hasAppliedReward = true; 
        rewardToClear = user.pendingReward;
      }
    }

    if (promoCode && promoCode.trim() !== "") {
      const promo = await PromoCode.findOne({ code: promoCode.toUpperCase(), isActive: true });
      if (promo) {
        const alreadyUsed = promo.usedBy && promo.usedBy.includes(userId);
        if (!alreadyUsed && (promo.targetUsers === 0 || promo.usageCount < promo.targetUsers)) {
          amount -= (amount * promo.discount) / 100;
          promo.usageCount += 1;
          promo.usedBy.push(userId);
          await promo.save();
        }
      }
    }

    // 2. Check if the SPOT is already reserved during this time
    const spotOverlap = await Reservation.findOne({
      spotId,
      status: { $in: ['pending', 'active'] },
      $or: [{ startTime: { $lt: end }, endTime: { $gt: start } }]
    });

    if (spotOverlap) throw new AppError('This spot is already reserved during your selected time range.', 400, 'BE-RES-005');

    // 3. Check if the USER already has another overlapping reservation (on any spot)
    const userOverlap = await Reservation.findOne({
      userId,
      status: { $in: ['pending', 'active'] },
      $or: [{ startTime: { $lt: end }, endTime: { $gt: start } }]
    });

    if (userOverlap) {
       throw new AppError('You already have another active reservation that overlaps with this time range.', 400, 'BE-RES-016');
    }

    const reservation = await Reservation.create({
      userId, spotId, mallId, carPlate: carPlate || 'N/A',
      startTime: start, endTime: end,
      amount: Math.round(amount * 100) / 100,
      status: 'pending', pointsEarned, durationMinutes
    });
    createdReservationId = reservation._id;

    const userUpdate = { $inc: { points: pointsEarned } };
    if (hasAppliedReward) userUpdate.pendingReward = null;
    await User.findByIdAndUpdate(userId, userUpdate);
    pointsAddedToUser = true;
    pointsToRevert = pointsEarned;

    await PointHistory.create({
      userId, amount: pointsEarned, mallId,
      reason: `Reservation at ${mall.name || 'Mall'}`,
      createdAt: new Date()
    });

    await Spot.findByIdAndUpdate(spotId, { reservationId: reservation._id });
    
    // --- REAL-TIME STATUS EMISSION ---
    // Instead of waiting up to 10s for the sync job, calculate and emit now
    const io = req.app.get('io');
    if (io) {
      const now = new Date();
      const start = new Date(startTime);
      const end = new Date(endTime);
      
      let immediateStatus = 'green';
      const arrivalThreshold = new Date(start.getTime() - 15 * 60 * 1000);
      const exitThreshold = new Date(end.getTime() - 15 * 60 * 1000);
      
      if (now >= end) {
        immediateStatus = 'green';
      } else if (now >= exitThreshold) {
        immediateStatus = 'yellow';
      } else if (now >= arrivalThreshold) {
        immediateStatus = 'red';
      }
      
      if (immediateStatus !== 'green') {
        // Update spot status in DB immediately
        await Spot.findByIdAndUpdate(spotId, { status: immediateStatus });
        // Emit via socket
        io.emit('spot_status_changed', { 
          spotId: spotId.toString(), 
          mallId: mallId.toString(), 
          status: immediateStatus 
        });
        console.log(`[SOCKET] Immediate status emit for Spot ${spotId}: ${immediateStatus}`);
      }
    }

    res.json({ success: true, message: 'Reservation created successfully!', reservation, amount });

  } catch (error) {
    if (createdReservationId) await Reservation.findByIdAndDelete(createdReservationId);
    if (spotToRevert) await Spot.findByIdAndUpdate(spotToRevert, { status: 'green', reservationId: null });
    
    if (pointsAddedToUser || hasAppliedReward) {
      const revertUpdate = {};
      if (pointsAddedToUser) revertUpdate.$inc = { points: -pointsToRevert };
      if (hasAppliedReward) revertUpdate.pendingReward = rewardToClear;
      await User.findByIdAndUpdate(userId, revertUpdate);
    }
    next(error); // Pass to global error handler
  }
});

// ----------------------------------------------------------
// GET MY ACTIVITY — List all reservations for the logged-in user
// GET /api/reservation/activity
// Returns: Array of reservations with mall name and spot number.
// Used by the Activity screen to show booking history.
// ----------------------------------------------------------
exports.getMyActivity = catchAsync(async (req, res, next) => {
  const reservations = await Reservation.find({ userId: req.user.id })
    .populate('mallId', 'name')
    .populate('spotId', 'spotNumber')
    .sort({ createdAt: -1 })
    .lean();
  res.json(reservations);
});

// ----------------------------------------------------------
// CANCEL RESERVATION — User or admin cancels a booking
// DELETE /api/reservation/:id
// Frees the spot (sets status to green) and emits update.
// Only the reservation owner or an admin can cancel.
// ----------------------------------------------------------
exports.cancelReservation = catchAsync(async (req, res, next) => {
    const reservation = await Reservation.findById(req.params.id);
    if (!reservation) return next(new AppError('Reservation not found', 404, 'BE-RES-006'));
    
    if (reservation.userId.toString() !== req.user.id && req.user.role !== 'admin') {
      return next(new AppError('Not authorized', 403, 'BE-RES-007'));
    }
    
    reservation.status = 'cancelled';
    await reservation.save();
    
    await Spot.findByIdAndUpdate(reservation.spotId, { status: 'green', reservationId: null });
    
    const io = req.app.get('io');
    if (io) {
      io.emit('spot_status_changed', { spotId: reservation.spotId, mallId: reservation.mallId, status: 'green' });
    }
    res.json({ success: true });
});

// ----------------------------------------------------------
// UPDATE RESERVATION STATUS — Verify arrival or change status
// PUT /api/reservation/:id/status
// Body: { status: "Active" | "Cancelled Early" | "Completed" }
//
// Most importantly, when status = "Active":
//   1. Checks user is within 15 minutes of start time
//   2. Sets actualStartTime to NOW
//   3. Recalculates endTime based on remaining duration
//   4. Changes spot color to RED
//   5. Opens the physical gate via IoT manager
// ----------------------------------------------------------
exports.updateReservationStatus = catchAsync(async (req, res, next) => {
    const { status } = req.body;
    const normalizedStatus = normalize(status);
    
    const reservation = await Reservation.findById(req.params.id);
    if (!reservation) return next(new AppError('Reservation not found', 404, 'BE-RES-008'));

    const statusMap = { 'active': 'active', 'cancelled early': 'cancelled', 'cancelled': 'cancelled', 'completed': 'completed', 'pending': 'pending' };
    const canonicalStatus = statusMap[normalizedStatus] || normalizedStatus;

    reservation.status = canonicalStatus;

    if (canonicalStatus === 'active') {
      const now = new Date();
      const startTime = new Date(reservation.startTime);
      const threshold = new Date(startTime.getTime() - 15 * 60 * 1000);
      
      if (now < threshold) {
        return next(new AppError('Arrival verification is only available starting 15 minutes before your scheduled arrival time.', 400, 'BE-RES-009'));
      }

      reservation.actualStartTime = now;
      reservation.endTime = new Date(now.getTime() + (reservation.durationMinutes || 60) * 60000);
      reservation.gateOpened = true;
      reservation.carEntered = true; // Car is entering the spot — IR monitoring begins now
      await reservation.save();

      await Spot.findByIdAndUpdate(reservation.spotId, { status: 'red', reservationId: reservation._id });
      const io = req.app.get('io');
      if (io) io.emit('spot_status_changed', { spotId: reservation.spotId, mallId: reservation.mallId, status: 'red' });

      // Trigger physical gate open
      const iotManager = req.app.get('iotManager');
      if (iotManager) iotManager.openGate(reservation.spotId);

    } else if (canonicalStatus === 'completed' || canonicalStatus === 'cancelled') {
      reservation.gateOpened = false; // Set gateOpened to false
      await reservation.save();
      await Spot.findByIdAndUpdate(reservation.spotId, { status: 'green', reservationId: null });
      const io = req.app.get('io');
      if (io) io.emit('spot_status_changed', { spotId: reservation.spotId, mallId: reservation.mallId, status: 'green' });

      // Trigger physical gate close
      const iotManager = req.app.get('iotManager');
      if (iotManager) iotManager.closeGate(reservation.spotId);

    } else {
      await reservation.save();
    }

    res.json({ success: true, reservation });
});

// ----------------------------------------------------------
// VALIDATE PROMO CODE — Check if a promo code is valid
// POST /api/reservation/validate-promo
// Body: { code: "SUMMER25" }
// Returns the discount percentage if valid.
// Used during reservation to preview discount before confirming.
// ----------------------------------------------------------
exports.validatePromoCode = catchAsync(async (req, res, next) => {
    const { code } = req.body;
    if (!code) return next(new AppError('Promo code is required.', 400, 'BE-RES-010'));

    const promo = await PromoCode.findOne({ code: code.toUpperCase(), isActive: true });
    if (!promo) return next(new AppError('Invalid or inactive promo code.', 404, 'BE-RES-011'));

    if (promo.targetUsers > 0 && promo.usageCount >= promo.targetUsers) {
      return next(new AppError('Promo code usage limit reached.', 400, 'BE-RES-012'));
    }

    if (promo.usedBy && promo.usedBy.includes(req.user.id)) {
      return next(new AppError('You have already used this promo code.', 400, 'BE-RES-013'));
    }

    res.json({
      success: true,
      code: promo.code,
      discount: promo.discount,
      message: `Promo code ${promo.code} applied: ${promo.discount}% off!`
    });
});

// ----------------------------------------------------------
// HANDLE LEAVE EARLY RESPONSE — User responds to "Are you leaving?"
// PUT /api/reservation/:id/leave-early
// Body: { leaveEarly: true | false }
//
// Called when the IoT sensor detects the car left the spot.
// If YES (leaving early):
//   → Complete reservation, free spot, close gate
// If NO (keeping spot):
//   → Close gate, set needsReverify=true, emit reverify_required
//   → User must re-enter plate to open gate again
// ----------------------------------------------------------
exports.handleLeaveEarlyResponse = catchAsync(async (req, res, next) => {
    const { leaveEarly } = req.body;
    const reservationId = req.params.id;

    const reservation = await Reservation.findById(reservationId);
    if (!reservation) {
      return next(new AppError('Reservation not found.', 404, 'BE-RES-015'));
    }

    const iotManager = req.app.get('iotManager');
    const io = req.app.get('io');

    if (leaveEarly === true) {
      // User IS leaving early → complete reservation, free the spot, close gate
      reservation.status = 'completed';
      reservation.needsReverify = false;
      reservation.gateOpened = false;
      await reservation.save();

      await Spot.findByIdAndUpdate(reservation.spotId, { status: 'green', reservationId: null });
      if (io) {
        io.emit('spot_status_changed', {
          spotId: reservation.spotId,
          mallId: reservation.mallId,
          status: 'green'
        });
      }

      if (iotManager) iotManager.closeGate(reservation.spotId);
      console.log(`[LEAVE EARLY] Spot marked as available & gate closed for spot ${reservation.spotId}`);
    } else {
      // User is NOT leaving early → keep reservation active, just reset carEntered
      // so the IR sensor can detect when the car returns.
      // No gate close, no plate re-verification needed.
      reservation.carEntered = false;
      reservation.needsReverify = false;
      await reservation.save();

      console.log(`[LEAVE EARLY] User keeping spot ${reservation.spotId}. Reservation stays active. carEntered reset for re-detection.`);
    }

    res.json({ success: true, status: reservation.status });
});

// ----------------------------------------------------------
// RE-VERIFY PLATE — User re-enters plate to re-open the gate
// PUT /api/reservation/:id/reverify
// Body: { carPlate: "ABC1234" }
//
// Called after user chose "No, keeping my spot" and the gate closed.
// Validates the plate matches the reservation's carPlate.
// If correct: clears needsReverify, opens gate, continues reservation.
// If wrong: returns error, user can try again.
// ----------------------------------------------------------
exports.reverifyPlate = catchAsync(async (req, res, next) => {
    const { carPlate } = req.body;
    const reservationId = req.params.id;

    if (!carPlate) {
      return next(new AppError('Car plate is required.', 400, 'BE-RES-017'));
    }

    const reservation = await Reservation.findById(reservationId);
    if (!reservation) {
      return next(new AppError('Reservation not found.', 404, 'BE-RES-018'));
    }

    if (reservation.userId.toString() !== req.user.id) {
      return next(new AppError('Not authorized.', 403, 'BE-RES-019'));
    }

    if (!reservation.needsReverify) {
      return next(new AppError('Re-verification is not required for this reservation.', 400, 'BE-RES-020'));
    }

    // Compare plate numbers (case-insensitive)
    const inputPlate = carPlate.trim().toUpperCase();
    const actualPlate = (reservation.carPlate || '').trim().toUpperCase();

    if (inputPlate !== actualPlate) {
      return next(new AppError('Incorrect plate number. Please try again.', 400, 'BE-RES-021'));
    }

    // Plate matches → clear reverify flag, mark car as entered, open the gate
    reservation.needsReverify = false;
    reservation.carEntered = true;
    reservation.gateOpened = true; // Set gateOpened to true
    await reservation.save();

    const iotManager = req.app.get('iotManager');
    if (iotManager) iotManager.openGate(reservation.spotId);

    console.log(`[RE-VERIFY] Plate verified for spot ${reservation.spotId}. Gate opening.`);

    res.json({ success: true, message: 'Plate verified. Gate opening.' });
});

// ----------------------------------------------------------
// OPEN GATE — Manually open the gate for an active reservation
// PUT /api/reservation/:id/open-gate
// ----------------------------------------------------------
exports.openGate = catchAsync(async (req, res, next) => {
    const reservationId = req.params.id;
    const reservation = await Reservation.findById(reservationId);
    
    if (!reservation) {
      return next(new AppError('Reservation not found.', 404, 'BE-RES-022'));
    }

    if (reservation.userId.toString() !== req.user.id && req.user.role !== 'admin') {
      return next(new AppError('Not authorized.', 403, 'BE-RES-023'));
    }

    if (reservation.status !== 'active') {
      return next(new AppError('Gate control is only available for active reservations.', 400, 'BE-RES-024'));
    }

    const iotManager = req.app.get('iotManager');
    let sent = false;
    if (iotManager) {
      sent = iotManager.openGate(reservation.spotId);
    }

    if (!sent) {
      return next(new AppError('Failed to send open command. IoT device is not connected.', 400, 'BE-RES-025'));
    }

    // Synchronize state in MongoDB
    reservation.gateOpened = true;
    await reservation.save();

    res.json({ success: true, message: 'Gate opening command sent.', reservation });
});

// ----------------------------------------------------------
// CLOSE GATE — Manually close the gate for an active reservation
// PUT /api/reservation/:id/close-gate
// ----------------------------------------------------------
exports.closeGate = catchAsync(async (req, res, next) => {
    const reservationId = req.params.id;
    const reservation = await Reservation.findById(reservationId);
    
    if (!reservation) {
      return next(new AppError('Reservation not found.', 404, 'BE-RES-026'));
    }

    if (reservation.userId.toString() !== req.user.id && req.user.role !== 'admin') {
      return next(new AppError('Not authorized.', 403, 'BE-RES-027'));
    }

    if (reservation.status !== 'active') {
      return next(new AppError('Gate control is only available for active reservations.', 400, 'BE-RES-028'));
    }

    const iotManager = req.app.get('iotManager');
    let sent = false;
    if (iotManager) {
      sent = iotManager.closeGate(reservation.spotId);
    }

    if (!sent) {
      return next(new AppError('Failed to send close command. IoT device is not connected.', 400, 'BE-RES-029'));
    }

    // Synchronize state in MongoDB
    reservation.gateOpened = false;
    await reservation.save();

    res.json({ success: true, message: 'Gate closing command sent.', reservation });
});

