// backend/scripts/load_test.js
const axios = require('axios');

const URL = 'http://localhost:5000/api/mall';
const CONCURRENT_REQUESTS = 50;

async function runLoadTest() {
  console.log(`--- iPark Load Test: Simulating ${CONCURRENT_REQUESTS} users ---`);
  
  const start = Date.now();
  const promises = [];

  for (let i = 0; i < CONCURRENT_REQUESTS; i++) {
    promises.push(axios.get(URL).catch(e => ({ status: 'error', message: e.message })));
  }

  const results = await Promise.all(promises);
  const end = Date.now();

  const succeded = results.filter(r => r.status === 200).length;
  const failed = CONCURRENT_REQUESTS - succeded;

  console.log(`Total Duration: ${end - start}ms`);
  console.log(`Succeeded: ${succeded}`);
  console.log(`Failed: ${failed}`);
  console.log(`Throughput: ${(succeded / ((end - start) / 1000)).toFixed(2)} req/sec`);
}

runLoadTest();
