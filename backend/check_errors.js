
require('dotenv').config();
const mongoose = require('mongoose');
const ErrorLog = require('./models/ErrorLog');
const connectDB = require('./config/db');

async function checkRecentErrors() {
    await connectDB();
    console.log('Connected to DB...');
    
    // Find the most recent FE-GEN-001 error from the last 10 minutes
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
    const logs = await ErrorLog.find({ 
        errorCode: 'FE-GEN-001',
        createdAt: { $gte: tenMinutesAgo }
    }).sort({ createdAt: -1 }).limit(1).lean();

    if (logs.length > 0) {
        console.log('--- LATEST FRONTEND ERROR ---');
        console.log('Time:', logs[0].createdAt);
        console.log('Message:', logs[0].message);
        console.log('Path:', logs[0].path);
        console.log('Metadata:', JSON.stringify(logs[0].metadata, null, 2));
        console.log('Stack Trace Snippet:', logs[0].stack ? logs[0].stack.substring(0, 500) + '...' : 'No stack');
    } else {
        console.log('No recent FE-GEN-001 errors found.');
    }
    
    await mongoose.connection.close();
}

checkRecentErrors();
