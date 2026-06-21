const mongoose = require('mongoose');
const Mall = require('./models/Mall');
require('dotenv').config();

async function checkMalls() {
  const uri = process.env.MONGO_URI || 'mongodb://localhost:27017/ipark';
  await mongoose.connect(uri);
  const malls = await Mall.find();
  console.log('--- MALL PRICES ---');
  malls.forEach(m => {
    console.log(`Name: ${m.name}, PricePerPage: ${m.pricePerHour}`);
  });
  process.exit();
}

checkMalls();
