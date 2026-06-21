// backend/scripts/reset_db.js
const mongoose = require('mongoose');
require('dotenv').config({ path: '../.env' });

const User = require('../models/User');
const Mall = require('../models/Mall');
const Reservation = require('../models/Reservation');
const Spot = require('../models/Spot');

async function resetPart(type) {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log("Connected to database...");

        switch (type) {
            case 'users':
                const userResult = await User.deleteMany({ role: { $ne: 'admin' } });
                console.log(`✅ Non-Admin Users Cleared: ${userResult.deletedCount} users removed.`);
                break;
            case 'reservations':
                const resResult = await Reservation.deleteMany({});
                console.log(`✅ Reservations Cleared: ${resResult.deletedCount} items removed.`);
                break;
            case 'malls':
                const mallResult = await Mall.deleteMany({});
                const spotResult = await Spot.deleteMany({});
                console.log(`✅ Malls Cleared: ${mallResult.deletedCount} malls and ${spotResult.deletedCount} spots removed.`);
                break;
            case 'all':
                await User.deleteMany({ role: { $ne: 'admin' } });
                await Mall.deleteMany({});
                await Reservation.deleteMany({});
                await Spot.deleteMany({});
                console.log("✅ Partial Reset Complete! Malls and Reservations cleared, ADMINS kept.");
                break;
            default:
                console.log("Error: Please specify what to reset (users, reservations, malls, or all).");
                console.log("Usage: node reset_db.js users");
        }

        mongoose.connection.close();
    } catch (error) {
        console.error("Error resetting database:", error.message);
        process.exit(1);
    }
}

const type = process.argv[2];
resetPart(type);
