// backend/scripts/seed_db.js
const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const User = require('../models/User');
const Mall = require('../models/Mall');
const Spot = require('../models/Spot');
const Reservation = require('../models/Reservation');

async function seed() {
  const uri = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/ipark';
  try {
    console.log(`Connecting to MongoDB at: ${uri}`);
    await mongoose.connect(uri);
    console.log('Connected to MongoDB.');

    // 1. Clear existing data
    console.log('Clearing existing database collections...');
    await User.deleteMany({});
    await Mall.deleteMany({});
    await Spot.deleteMany({});
    await Reservation.deleteMany({});
    console.log('Cleared database successfully.');

    // 2. Create Admin and Test Users
    console.log('Creating users...');
    const admin = await User.create({
      name: 'Admin User',
      email: 'admin@ipark.com',
      phoneNumber: '07701112223',
      nationalId: '1112223334',
      role: 'admin',
      isVerified: true
    });

    const user = await User.create({
      name: 'Mario Test',
      email: 'mario@ipark.com',
      phoneNumber: '07701234567',
      nationalId: '1234567890',
      carPlate: 'BAG-98765',
      role: 'user',
      isVerified: true
    });
    console.log(`Users created: Admin (${admin.email}), User (${user.email})`);

    // 3. Create a Test Mall
    console.log('Creating Grand Plaza Mall...');
    const mall = await Mall.create({
      name: 'Grand Plaza Mall',
      location: 'Baghdad',
      description: 'Premium shopping mall with automated smart parking system.',
      address: 'Al-Mansour District, Baghdad',
      totalSpots: 3,
      pricePerHour: 1000
    });
    console.log(`Mall created: ${mall.name} (ID: ${mall._id})`);

    // 4. Create Spots (linking to the Mall)
    // We explicitly set the ID of the first spot to match the default ID in gate_controller.ino: '69cd86659c1a5e779d63af04'
    const targetSpotId = '69cd86659c1a5e779d63af04';
    console.log(`Creating parking spots (A-1 with target ID: ${targetSpotId})...`);
    
    const spot1 = await Spot.create({
      _id: new mongoose.Types.ObjectId(targetSpotId),
      mallId: mall._id,
      spotNumber: 'A-1',
      status: 'red' // Red because there is an active reservation
    });

    const spot2 = await Spot.create({
      mallId: mall._id,
      spotNumber: 'A-2',
      status: 'green'
    });

    const spot3 = await Spot.create({
      mallId: mall._id,
      spotNumber: 'A-3',
      status: 'green'
    });
    console.log('Parking spots created.');

    // 5. Create an Active Reservation for spot1 (A-1)
    // For the IoT device to communicate status updates, there must be an active reservation for that spot.
    console.log('Creating an active reservation for A-1...');
    const now = new Date();
    const startTime = new Date(now.getTime() - 60 * 60 * 1000); // 1 hour ago
    const endTime = new Date(now.getTime() + 3 * 60 * 60 * 1000); // 3 hours from now

    const reservation = await Reservation.create({
      userId: user._id,
      spotId: spot1._id,
      mallId: mall._id,
      carPlate: user.carPlate,
      startTime: startTime,
      endTime: endTime,
      status: 'active',
      amount: 4000,
      pointsEarned: 40,
      carEntered: false,
      gateOpened: true
    });

    // Link the active reservation back to the Spot document
    spot1.reservationId = reservation._id;
    spot1.reservedBy = user._id;
    await spot1.save();

    console.log(`Active reservation created for ${user.name} on spot ${spot1.spotNumber}.`);
    console.log('Reservation ID:', reservation._id);

    console.log('\n=========================================');
    console.log('🎉 DATABASE SEEDING COMPLETED SUCCESSFULLY!');
    console.log('=========================================');
    console.log(`Test Spot ID: ${spot1._id}`);
    console.log(`Test User Phone (OTP Login): ${user.phoneNumber}`);
    console.log(`Test Admin Phone: ${admin.phoneNumber}`);
    console.log('You can now connect the IoT device!');
  } catch (err) {
    console.error('Seeding failed:', err);
  } finally {
    await mongoose.disconnect();
    process.exit();
  }
}

seed();
