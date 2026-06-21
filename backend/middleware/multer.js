// backend/middleware/multer.js
// ============================================================
// FILE UPLOAD MIDDLEWARE — Handles image uploads using Multer.
// Used for two types of uploads:
//   1. Profile photos → saved to uploads/profiles/
//   2. Mall photos → saved to uploads/malls/
// Only allows JPEG, PNG, and WEBP files up to 10MB.
// Files are renamed with a unique timestamp to prevent collisions.
// ============================================================
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// --- Create upload directories if they don't exist ---
const uploadDirs = ['uploads/profiles', 'uploads/malls'];
uploadDirs.forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

// --- Storage Configuration ---
// Decides WHERE to save the file and WHAT to name it
const storage = multer.diskStorage({
    // Choose destination folder based on which upload field is used
    destination: (req, file, cb) => {
        let dest = 'uploads/profiles';  // Default: profile photos
        if (file.fieldname === 'mallPhoto' || req.originalUrl.includes('mall')) {
            dest = 'uploads/malls';     // Mall photos go here
        }
        cb(null, dest);
    },
    // Generate a unique filename: e.g., "profile-1718234567890-482947.jpg"
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);  // Keep original extension
        const prefix = file.fieldname === 'mallPhoto' ? 'mall' : 'profile';
        cb(null, `${prefix}-${uniqueSuffix}${ext}`);
    }
});

// --- File Type Filter ---
// Only allow image files (reject PDFs, videos, etc.)
const fileFilter = (req, file, cb) => {
    const filetypes = /jpeg|jpg|png|webp/;
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = filetypes.test(file.mimetype);

    if (mimetype || extname) {
        return cb(null, true);   // Accept the file
    } else {
        cb(new Error('Only images (JPEG, PNG, WEBP) are allowed!'), false);
    }
};

// --- Create and export the configured Multer instance ---
const upload = multer({
    storage: storage,
    fileFilter: fileFilter,
    limits: {
        fileSize: 10 * 1024 * 1024  // Max file size: 10MB
    }
});

module.exports = upload;
