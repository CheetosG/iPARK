// backend/config/db.js
// ============================================================
// DATABASE CONNECTION — Connects the server to MongoDB.
// Uses the MONGO_URI from the .env file (or defaults to localhost).
// If the connection fails, it prints troubleshooting tips and exits.
// Called once during server startup in server.js.
// ============================================================
const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    // Connect to MongoDB using the URI from environment variables
    // Falls back to local MongoDB if no URI is specified
    const conn = await mongoose.connect(
      process.env.MONGO_URI || 'mongodb://localhost:27017/ipark',
      {
        serverSelectionTimeoutMS: 5000,  // Fail fast (5s instead of default 30s)
        socketTimeoutMS: 45000,          // Close idle connections after 45s
      }
    );
    console.log(`MongoDB Connected: ${conn.connection.host}`);
  } catch (error) {
    // --- Connection Failed: Print helpful troubleshooting guide ---
    console.error('\n\x1b[31m%s\x1b[0m', '======================================================================');
    console.error('\x1b[31m%s\x1b[0m', '                 DATABASE CONNECTION ERROR DETECTED');
    console.error('\x1b[31m%s\x1b[0m', '======================================================================');
    console.error(`Error details: ${error.message}\n`);
    console.error('\x1b[33m%s\x1b[0m', '👉 POSIBLE SOLUTIONS:');
    console.error('\x1b[33m%s\x1b[0m', '1. IP Whitelist Issue (Most Common):');
    console.error('   Your current IP address is likely not whitelisted in MongoDB Atlas.');
    console.error('   Go to: https://cloud.mongodb.com/ -> Network Access -> Add IP Address');
    console.error('   Click "Allow Access From Anywhere" (0.0.0.0/0) to fix this permanently.');
    console.error('\x1b[33m%s\x1b[0m', '2. Local Database Issue:');
    console.error('   If running a local DB, ensure MongoDB service is started on your PC.');
    console.error('\x1b[31m%s\x1b[0m', '======================================================================\n');
    process.exit(1);  // Stop the server — can't run without a database
  }
};

module.exports = connectDB;