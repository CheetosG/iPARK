// backend/utils/paymentMock.js
// ============================================================
// MOCK PAYMENT PROCESSOR — Simulates a payment gateway for testing.
// In production, this would be replaced with a real payment API
// (e.g., Stripe, PayPal, or a local payment provider).
// Currently:
//   - Rejects card numbers shorter than 16 digits
//   - Approves everything else after a 1.5 second fake delay
//   - Returns a fake transaction ID (TXN-timestamp)
// ============================================================

exports.processPayment = async (amount, cardNumber) => {
  return new Promise((resolve, reject) => {
    // Simulate network delay (1.5 seconds like a real payment API)
    setTimeout(() => {
      // Basic validation: real card numbers are 16 digits
      if (cardNumber.length < 16) {
        reject({ success: false, message: 'Invalid Card Number' });
      } else {
        // Payment approved! Return a fake transaction receipt
        resolve({
          success: true,
          transactionId: `TXN-${Date.now()}`,  // Unique transaction ID
          amount: amount,
          message: 'Payment Confirmed'
        });
      }
    }, 1500);
  });
};