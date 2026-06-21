// backend/utils/otpGenerator.js
// ============================================================
// OTP (One-Time Password) GENERATOR — Handles phone verification.
// When a user tries to log in:
//   1. generateOTP(phone) creates a 6-digit code, stores it in memory
//   2. The code is printed to console (in production, send via SMS)
//   3. verifyOTP(phone, code) checks if the entered code matches
//   4. Codes expire after 1 minute
// OTPs are stored in-memory (Map), not in MongoDB — they're temporary.
// A cleanup job runs every 5 minutes to remove expired codes.
// ============================================================

// --- In-memory store: phone number → { otp, createdAt, expiresAt } ---
const otpStore = new Map();

// ----------------------------------------------------------
// GENERATE OTP
// Creates a random 6-digit code and stores it for the given phone number.
// Returns the OTP string (e.g., "482917").
// ----------------------------------------------------------
exports.generateOTP = (phoneNumber) => {
  // Generate a random 6-digit number between 100000 and 999999
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Store with 1-minute expiration
  otpStore.set(phoneNumber, {
    otp: otp,
    createdAt: Date.now(),
    expiresAt: Date.now() + 60000  // Expires in 60 seconds
  });
  
  // Print to console (in production, this would be sent via SMS API)
  console.log(`[OTP DEBUG] Generated OTP for ${phoneNumber}: ${otp}`);
  console.log(`[OTP DEBUG] Store:`, Array.from(otpStore.entries()));
  return otp;
};

// ----------------------------------------------------------
// VERIFY OTP
// Checks if the entered OTP matches the stored one.
// Returns true if valid, false if invalid/expired/not found.
// Deletes the OTP after successful verification (single use).
// ----------------------------------------------------------
exports.verifyOTP = (phoneNumber, enteredOTP) => {
  const storedData = otpStore.get(phoneNumber);
  
  console.log(`[OTP DEBUG] Verifying for ${phoneNumber}`);
  console.log(`[OTP DEBUG] Entered OTP: ${enteredOTP}`);
  console.log(`[OTP DEBUG] Stored OTP: ${storedData?.otp}`);
  
  // No OTP was generated for this phone number
  if (!storedData) {
    console.log(`[OTP ERROR] No OTP found for ${phoneNumber}`);
    return false;
  }
  
  // OTP has expired (older than 1 minute)
  if (Date.now() > storedData.expiresAt) {
    console.log(`[OTP ERROR] OTP expired for ${phoneNumber}`);
    otpStore.delete(phoneNumber);
    return false;
  }
  
  // OTP matches — success!
  if (storedData.otp === enteredOTP) {
    console.log(`[OTP SUCCESS] Verified for ${phoneNumber}`);
    otpStore.delete(phoneNumber);  // One-time use: delete after verification
    return true;
  }
  
  // OTP doesn't match
  console.log(`[OTP ERROR] Mismatch for ${phoneNumber}`);
  return false;
};

// ----------------------------------------------------------
// CLEANUP JOB
// Runs every 5 minutes to remove any OTPs that expired but
// were never verified (prevents memory leaks).
// ----------------------------------------------------------
setInterval(() => {
  const now = Date.now();
  otpStore.forEach((value, key) => {
    if (now > value.expiresAt) {
      otpStore.delete(key);
      console.log(`[OTP CLEANUP] Removed expired OTP for ${key}`);
    }
  });
}, 300000);  // 300,000ms = 5 minutes