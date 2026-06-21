const mongoose = require('mongoose');
const User = require('./models/User');
require('dotenv').config();

async function run() {
  const uri = process.env.MONGO_URI || 'mongodb://localhost:27017/ipark';
  try {
    await mongoose.connect(uri);
    console.log('Connected to MongoDB.');
    
    const users = await User.find().lean();
    console.log('--- ALL USERS ---');
    if (users.length === 0) {
      console.log('No users found in the database!');
    } else {
      users.forEach((user, idx) => {
        console.log(`[${idx+1}] ID: ${user._id}`);
        console.log(`Phone: ${user.phoneNumber}`);
        console.log(`Name: ${user.name}`);
        console.log(`Role: ${user.role}`);
        console.log('------------------------');
      });
    }
  } catch (err) {
    console.error('Error running script:', err);
  } finally {
    await mongoose.disconnect();
    process.exit();
  }
}

run();
