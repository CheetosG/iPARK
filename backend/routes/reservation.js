// backend/routes/reservation.js
// ============================================================
// RESERVATION ROUTES — All routes require authentication.
// These handle the full reservation lifecycle:
//   Book → Verify Arrival → Leave Early? → Re-verify plate
// ============================================================
const express = require('express');
const router = express.Router();
const reservationController = require('../controllers/reservationController');
const { authMiddleware } = require('../middleware/auth');

// Create a new reservation (book a parking spot)
// POST /api/reservation { spotId, mallId, carPlate, startTime, endTime, promoCode? }
router.post('/', authMiddleware, reservationController.createReservation);

// Get the logged-in user's reservation history (Activity screen)
// GET /api/reservation/activity
router.get('/activity', authMiddleware, reservationController.getMyActivity);

// Validate a promo code before creating a reservation
// POST /api/reservation/validate-promo { code }
router.post('/validate-promo', authMiddleware, reservationController.validatePromoCode);

// Cancel a reservation (frees the spot)
// DELETE /api/reservation/:id
router.delete('/:id', authMiddleware, reservationController.cancelReservation);

// Update reservation status (used for arrival verification)
// PUT /api/reservation/:id/status { status: "Active" | "Cancelled Early" | "Completed" }
router.put('/:id/status', authMiddleware, reservationController.updateReservationStatus);

// Respond to "Are you leaving early?" prompt from IoT sensor
// PUT /api/reservation/:id/leave-early { leaveEarly: true | false }
router.put('/:id/leave-early', authMiddleware, reservationController.handleLeaveEarlyResponse);

// Re-verify plate number (after car-left detection + user chose to keep spot)
// PUT /api/reservation/:id/reverify { carPlate }
router.put('/:id/reverify', authMiddleware, reservationController.reverifyPlate);

// Manually open the gate for an active reservation
// PUT /api/reservation/:id/open-gate
router.put('/:id/open-gate', authMiddleware, reservationController.openGate);

// Manually close the gate for an active reservation
// PUT /api/reservation/:id/close-gate
router.put('/:id/close-gate', authMiddleware, reservationController.closeGate);

module.exports = router;