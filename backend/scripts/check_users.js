
const mongoose = require('mongoose');
require('dotenv').config();
const User = require('../models/User');

async function checkUsers() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');
    
    const users = await User.find({ role: { $in: ['admin', 'support'] } });
    console.log('Admin/Support Users:');
    users.forEach(u => {
      console.log(`- ${u.name} (${u.phoneNumber}): Role=${u.role}, Email=${u.email}`);
    });
    
    await mongoose.connection.close();
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

checkUsers();
