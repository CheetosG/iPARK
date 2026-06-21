// backend/scripts/test_security.js
require('dotenv').config();
const axios = require('axios');
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');

// Port for integration testing
process.env.PORT = 5001;
process.env.NODE_ENV = 'test';

// Start the server
require('../server');

const BASE_URL = 'http://127.0.0.1:5001/api/mall';
const LOG_FILE_PATH = path.join(__dirname, '..', 'security_audit.log');

async function runTests() {
  console.log('\n==================================================');
  console.log('   RUNNING iPARK STRIDE & SECURITY FAILSAFE TESTS  ');
  console.log('==================================================\n');

  // Wait for Mongo connection and server start
  await new Promise(resolve => setTimeout(resolve, 3000));

  const Spot = require('../models/Spot');
  const Mall = require('../models/Mall');

  // Create temporary mall and spot for testing
  let tempMall, tempSpot;
  try {
    tempMall = await Mall.create({
      name: 'Security Test Mall',
      location: 'Test Zone',
      totalSpots: 1,
      pricePerHour: 10
    });
    tempSpot = await Spot.create({
      mallId: tempMall._id,
      spotNumber: 'T-99',
      status: 'green'
    });
    console.log(`Created test Mall: ${tempMall._id}, Spot: ${tempSpot._id}\n`);
  } catch (err) {
    console.error('Failed to create test database models:', err.message);
    process.exit(1);
  }

  const endpointUrl = `${BASE_URL}/${tempMall._id}/spot/${tempSpot._id}/status`;
  let passed = 0;
  let failed = 0;

  // Clear previous log file content if exists
  if (fs.existsSync(LOG_FILE_PATH)) {
    fs.writeFileSync(LOG_FILE_PATH, '');
  }

  // --- TEST 1: Request without credentials ---
  try {
    console.log('[TEST 1] Sending update request with no credentials...');
    await axios.put(endpointUrl, { status: 'red' });
    console.error('❌ FAIL: Request succeeded but should have failed.');
    failed++;
  } catch (err) {
    if (err.response && err.response.status === 401 && err.response.data.errorCode === 'BE-SEC-UNAUTHORIZED') {
      console.log('✅ PASS: Rejected with 401 BE-SEC-UNAUTHORIZED');
      passed++;
    } else {
      console.error('❌ FAIL: Unexpected error response:', err.response ? err.response.data : err.message);
      failed++;
    }
  }

  // --- TEST 2: Request with invalid API Key ---
  try {
    console.log('\n[TEST 2] Sending update request with invalid API Key...');
    await axios.put(endpointUrl, { status: 'red' }, {
      headers: { 'x-api-key': 'wrong_api_key' }
    });
    console.error('❌ FAIL: Request succeeded but should have failed.');
    failed++;
  } catch (err) {
    if (err.response && err.response.status === 401 && err.response.data.errorCode === 'BE-SEC-UNAUTHORIZED') {
      console.log('✅ PASS: Rejected with 401 BE-SEC-UNAUTHORIZED');
      passed++;
    } else {
      console.error('❌ FAIL: Unexpected error response:', err.response ? err.response.data : err.message);
      failed++;
    }
  }

  // --- TEST 3: Request with valid API Key but invalid status (Data Tampering) ---
  try {
    console.log('\n[TEST 3] Sending invalid status ("blue") with valid API Key...');
    await axios.put(endpointUrl, { status: 'blue' }, {
      headers: { 'x-api-key': 'esp32_super_secret_key_123' }
    });
    console.error('❌ FAIL: Request succeeded but should have failed.');
    failed++;
  } catch (err) {
    if (err.response && err.response.status === 400 && err.response.data.errorCode === 'BE-SEC-TAMPERED') {
      console.log('✅ PASS: Rejected with 400 BE-SEC-TAMPERED');
      passed++;
    } else {
      console.error('❌ FAIL: Unexpected error response:', err.response ? err.response.data : err.message);
      failed++;
    }
  }

  // --- TEST 4: Device request with missing readings array ---
  try {
    console.log('\n[TEST 4] Sending device request with missing readings confirmation...');
    await axios.put(endpointUrl, { status: 'red' }, {
      headers: { 'x-api-key': 'esp32_super_secret_key_123' }
    });
    console.error('❌ FAIL: Request succeeded but should have failed.');
    failed++;
  } catch (err) {
    if (err.response && err.response.status === 400 && err.response.data.errorCode === 'BE-SEC-TAMPERED') {
      console.log('✅ PASS: Rejected with 400 BE-SEC-TAMPERED (missing readings)');
      passed++;
    } else {
      console.error('❌ FAIL: Unexpected error response:', err.response ? err.response.data : err.message);
      failed++;
    }
  }

  // --- TEST 5: Device request with inconsistent readings (Sensor Noise) ---
  try {
    console.log('\n[TEST 5] Sending device request with sensor noise (inconsistent readings)...');
    await axios.put(endpointUrl, { 
      status: 'red',
      readings: ['red', 'green', 'red'] 
    }, {
      headers: { 'x-api-key': 'esp32_super_secret_key_123' }
    });
    console.error('❌ FAIL: Request succeeded but should have failed.');
    failed++;
  } catch (err) {
    if (err.response && err.response.status === 400 && err.response.data.errorCode === 'BE-SEC-NOISE') {
      console.log('✅ PASS: Rejected with 400 BE-SEC-NOISE (sensor noise filtered)');
      passed++;
    } else {
      console.error('❌ FAIL: Unexpected error response:', err.response ? err.response.data : err.message);
      failed++;
    }
  }

  // --- TEST 6: Device request with valid API Key and consistent readings ---
  try {
    console.log('\n[TEST 6] Sending valid device request with consistent readings...');
    const response = await axios.put(endpointUrl, { 
      status: 'red',
      readings: ['red', 'red', 'red'] 
    }, {
      headers: { 'x-api-key': 'esp32_super_secret_key_123' }
    });
    if (response.data.success && response.data.spot.status === 'red') {
      console.log('✅ PASS: Spot updated to red successfully!');
      passed++;
    } else {
      console.error('❌ FAIL: Spot status was not updated correctly.');
      failed++;
    }
  } catch (err) {
    console.error('❌ FAIL: HTTP request failed:', err.response ? err.response.data : err.message);
    failed++;
  }

  // --- TEST 7: Check local log file for logged incidents ---
  try {
    console.log('\n[TEST 7] Verifying security events were recorded in security_audit.log...');
    if (fs.existsSync(LOG_FILE_PATH)) {
      const logs = fs.readFileSync(LOG_FILE_PATH, 'utf8');
      const testUnauthorized = logs.includes('BE-SEC-UNAUTHORIZED');
      const testTampered = logs.includes('BE-SEC-TAMPERED');
      const testNoise = logs.includes('BE-SEC-NOISE');

      if (testUnauthorized && testTampered && testNoise) {
        console.log('✅ PASS: Immutable log file matches all security events!');
        passed++;
      } else {
        console.error('❌ FAIL: Some security events were not found in security_audit.log.');
        console.error(`Logs present: UNAUTHORIZED: ${testUnauthorized}, TAMPERED: ${testTampered}, NOISE: ${testNoise}`);
        failed++;
      }
    } else {
      console.error('❌ FAIL: security_audit.log file was not created.');
      failed++;
    }
  } catch (err) {
    console.error('❌ FAIL: Log verification failed:', err.message);
    failed++;
  }

  // Clean up DB
  try {
    await Spot.findByIdAndDelete(tempSpot._id);
    await Mall.findByIdAndDelete(tempMall._id);
    console.log('\nCleaned up test database models.');
  } catch (err) {
    console.error('Failed to clean up test models:', err.message);
  }

  console.log('\n==================================================');
  console.log(`   SECURITY INTEGRATION RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('==================================================\n');

  // Close Mongoose connection and exit process
  await mongoose.connection.close();
  process.exit(failed > 0 ? 1 : 0);
}

runTests();
