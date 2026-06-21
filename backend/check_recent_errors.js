const mongoose = require('mongoose');
const ErrorLog = require('./models/ErrorLog');
require('dotenv').config();

async function run() {
  const uri = process.env.MONGO_URI || 'mongodb://localhost:27017/ipark';
  try {
    await mongoose.connect(uri);
    console.log('Connected to MongoDB.');
    
    const logs = await ErrorLog.find().sort({ createdAt: -1 }).limit(10).lean();
    console.log('--- LATEST 10 ERRORS IN DATABASE ---');
    if (logs.length === 0) {
      console.log('No error logs found!');
    } else {
      logs.forEach((log, idx) => {
        console.log(`[${idx+1}] Code: ${log.errorCode} | Time: ${log.createdAt}`);
        console.log(`Message: ${log.message}`);
        console.log(`Path: ${log.method || ''} ${log.path || ''}`);
        if (log.stack) {
          console.log(`Stack: ${log.stack.split('\n').slice(0, 3).join('\n')}`);
        }
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
