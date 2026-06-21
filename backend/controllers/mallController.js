// backend/controllers/mallController.js
// ============================================================
// MALL CONTROLLER — Handles mall and spot data for the Flutter app.
// Three endpoints:
//   1. getAllMalls — Returns all malls (shown on home screen)
//   2. getMallSpots — Returns all spots for a specific mall (shown on spots screen)
//   3. updateSpotStatus — Manually change a spot's color (admin use)
// ============================================================
const Mall = require('../models/Mall');
const Spot = require('../models/Spot');
const catchAsync = require('../utils/catchAsync');
const AppError = require('../utils/appError');

// ----------------------------------------------------------
// GET ALL MALLS
// GET /api/mall/
// Returns a list of all malls. No authentication required.
// The Flutter app shows these as cards on the home screen.
// ----------------------------------------------------------
exports.getAllMalls = catchAsync(async (req, res, next) => {
  const malls = await Mall.find();
  res.json(malls);
});

// ----------------------------------------------------------
// GET MALL SPOTS
// GET /api/mall/:id/spots
// Returns all parking spots for a specific mall.
// Includes the linked reservation data (endTime, status).
// The Flutter app uses this to render the colored spot grid.
// ----------------------------------------------------------
exports.getMallSpots = catchAsync(async (req, res, next) => {
  const spots = await Spot.find({ mallId: req.params.id })
    .populate('reservationId', 'endTime status')  // Include reservation endTime
    .lean();  // Return plain JS objects (faster, not Mongoose documents)
  
  res.json(spots);
});

// ----------------------------------------------------------
// UPDATE SPOT STATUS
// PUT /api/mall/:id/spot/:spotId/status
// Body: { status: "green" | "red" | "yellow" | "disabled" }
// Manually override a spot's status. Used by admins or the
// background sync job. Emits a real-time update to all clients.
// ----------------------------------------------------------
exports.updateSpotStatus = catchAsync(async (req, res, next) => {
  const { status } = req.body;
  const spot = await Spot.findByIdAndUpdate(req.params.spotId, { status }, { new: true });
  
  if (!spot) {
    return next(new AppError('Spot not found', 404, 'BE-MAL-001'));
  }

  // Broadcast the color change to all connected Flutter apps
  const io = req.app.get('io');
  if (io) {
    io.emit('spot_status_changed', { 
      spotId: req.params.spotId, 
      mallId: req.params.id, 
      status 
    });
  }
  
  res.json({ success: true, spot });
});
