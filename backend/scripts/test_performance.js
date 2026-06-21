// backend/scripts/test_performance.js
const axios = require('axios');

const BASE_URL = 'http://localhost:5000/api';

const endpoints = [
  { name: 'Get All Malls', url: `${BASE_URL}/mall` },
  { name: 'Health Check', url: `http://localhost:5000/health` }
];

async function measureLatency(endpoint) {
  const start = Date.now();
  try {
    await axios.get(endpoint.url);
    const end = Date.now();
    const duration = end - start;
    console.log(`[PASS] ${endpoint.name}: ${duration}ms`);
    return duration;
  } catch (error) {
    console.error(`[FAIL] ${endpoint.name}: ${error.message}`);
    return -1;
  }
}

async function runTests() {
  console.log('--- iPark Performance Benchmark ---');
  let totalLatency = 0;
  let count = 0;

  for (const ep of endpoints) {
    const latency = await measureLatency(ep);
    if (latency !== -1) {
      totalLatency += latency;
      count++;
    }
  }

  if (count > 0) {
    console.log(`Average Latency: ${(totalLatency / count).toFixed(2)}ms`);
    if ((totalLatency / count) < 2000) {
      console.log('STATUS: ✅ EXCELLENT (Sub-2s benchmark met)');
    } else {
      console.log('STATUS: ⚠️ SLOW (Above 2s benchmark)');
    }
  }
}

runTests();
