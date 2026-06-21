const mongoose = require('mongoose');
const ErrorLog = require('./models/ErrorLog');
require('dotenv').config();
const fs = require('fs');

async function checkError() {
  const uri = process.env.MONGO_URI || 'mongodb://localhost:27017/ipark';
  await mongoose.connect(uri);
  // Get all unique error codes from the last hour
  const errors = await ErrorLog.find({ 
    createdAt: { $gt: new Date(Date.now() - 3600000) } 
  }).sort({ createdAt: -1 });

  let output = '--- RECENT ERRORS (Last Hour) ---\n';
  if (errors.length > 0) {
    errors.forEach(err => {
      output += `Code: ${err.errorCode}\n`;
      output += `Message: ${err.message}\n`;
      output += `Path: ${err.path}\n`;
      output += `Method: ${err.method}\n`;
      output += `Stack: ${err.stack}\n`;
      output += `Time: ${err.createdAt}\n`;
      output += '---------------------------------\n';
    });
  } else {
    output = 'No errors found in the last hour.';
  }
  fs.writeFileSync('error_details.txt', output);
  process.exit();
}

checkError();
