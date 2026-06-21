// backend/scripts/set_admin.js
const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });
const User = require('../models/User');

async function makeAdmin(phoneNumber) {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log("Connected to database...");

        const user = await User.findOneAndUpdate(
            { phoneNumber: phoneNumber },
            { role: 'admin' },
            { new: true }
        );

        if (user) {
            console.log(`Success! User ${user.name} (${user.phoneNumber}) is now an ADMIN.`);
        } else {
            console.log("User not found. Please register first in the app.");
        }

        mongoose.connection.close();
    } catch (error) {
        console.error("Error:", error.message);
        process.exit(1);
    }
}

// Get phone number from command line or use a default if provided
const phone = process.argv[2];
if (!phone) {
    console.log("Please provide a phone number: node set_admin.js 0123456789");
    process.exit(1);
}

makeAdmin(phone);
