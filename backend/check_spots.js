const mongoose = require('mongoose');
const Spot = require('./models/Spot');
const Mall = require('./models/Mall');
require('dotenv').config();

async function run() {
  const uri = process.env.MONGO_URI || 'mongodb://localhost:27017/ipark';
  try {
    await mongoose.connect(uri);
    console.log('Connected to MongoDB.');
    
    const spots = await Spot.find().populate('mallId');
    console.log('--- ALL PARKING SPOTS ---');
    if (spots.length === 0) {
      console.log('No spots found in the database!');
    } else {
      spots.forEach(spot => {
        console.log(`Spot ID: ${spot._id}`);
        console.log(`Number: ${spot.number}`);
        console.log(`Mall: ${spot.mallId ? spot.mallId.name : 'Unknown'}`);
        console.log(`Status: ${spot.status}`);
        console.log(`Occupied: ${spot.occupied}`);
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
