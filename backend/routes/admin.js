// backend/routes/admin.js
// ============================================================
// ADMIN ROUTES — Protected routes for the admin dashboard.
// Different access levels:
//   - checkAdmin: Only admin role (add mall, create promo, update role)
//   - checkSupportOrAdmin: Admin + support staff (view users, ban, tickets)
// All routes require authMiddleware first (must be logged in).
// ============================================================
const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { authMiddleware, checkAdmin, checkSupportOrAdmin } = require('../middleware/auth');
const upload = require('../middleware/multer');

// --- Admin-only routes (requires admin role) ---

// Dashboard statistics (total users, revenue, etc.)
router.get('/stats', authMiddleware, checkAdmin, adminController.getStats);

// Add a new mall (with optional photo upload)
router.post('/add-mall', authMiddleware, checkAdmin, upload.single('mallPhoto'), adminController.addMall);

// Edit an existing mall
router.patch('/mall/:id', authMiddleware, checkAdmin, upload.single('mallPhoto'), adminController.updateMall);

// Promote a user to support staff role
router.post('/add-support', authMiddleware, checkAdmin, adminController.addSupport);

// Create a new promo/discount code
router.post('/create-promo', authMiddleware, checkAdmin, adminController.createPromoCode);

// Change a user's role (user ↔ support)
router.patch('/users/:id/role', authMiddleware, checkAdmin, adminController.updateRole);

// --- Staff routes (admin OR support can access) ---

// View all support tickets from users
router.get('/messages', authMiddleware, checkSupportOrAdmin, adminController.getMessages);

// View all registered users
router.get('/users', authMiddleware, checkSupportOrAdmin, adminController.getUsers);

// View a single user's details
router.get('/users/:id', authMiddleware, checkSupportOrAdmin, adminController.getUser);

// View a user's reservation history
router.get('/users/:id/history', authMiddleware, checkSupportOrAdmin, adminController.getUserHistory);

// Ban or unban a user
router.patch('/users/:id/ban', authMiddleware, checkSupportOrAdmin, adminController.toggleBan);

// Resolve (mark as solved) a support ticket
router.patch('/messages/:id', authMiddleware, checkSupportOrAdmin, adminController.resolveTicket);

module.exports = router;