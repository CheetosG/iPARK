// backend/routes/mall.js
// ============================================================
// MALL ROUTES — Public routes for browsing malls and spots.
// No authentication required (anyone can browse).
// Includes rate limiting on spot polling to prevent abuse.
// ============================================================
const express = require('express');
const router = express.Router();
const mallController = require('../controllers/mallController');
const rateLimit = require('express-rate-limit');

// Rate limiter for spot status polling (prevents Flutter app from hammering the API)
// Max 60 requests per minute per IP address
const spotLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,   // 1 minute window
  max: 60,                     // 60 requests max
  message: { message: 'Too many status checks, please wait.' }
});

// Get all malls (shown on the home screen as cards)
// GET /api/mall/
router.get('/', mallController.getAllMalls);

// Get all spots for a specific mall (shown as colored grid on spots screen)
// GET /api/mall/:id/spots  — rate limited
router.get('/:id/spots', spotLimiter, mallController.getMallSpots);

// Manually update a spot's status (admin/system use)
// PUT /api/mall/:id/spot/:spotId/status { status: "green" | "red" | "yellow" | "disabled" }
router.put('/:id/spot/:spotId/status', mallController.updateSpotStatus);

module.exports = router;