require('dotenv').config();
const mongoose = require('mongoose');

const uri = process.env.MONGODB_URI || 'mongodb://localhost/ipark';

mongoose.connect(uri).then(async () => {
  const result = await mongoose.connection.collection('reservations').updateMany(
    { needsReverify: true },
    { $set: { needsReverify: false, carEntered: false } }
  );
  console.log('Fixed', result.modifiedCount, 'reservations with needsReverify=true');
  process.exit(0);
}).catch(e => {
  console.error('Error:', e.message);
  process.exit(1);
});
