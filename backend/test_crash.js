const http = require('http');

const data = JSON.stringify({
  spotId: "60c72b2f9b1d8b001c8e4b3e",
  mallId: "60c72b2f9b1d8b001c8e4b3f",
  carPlate: "ABC-123",
  startTime: new Date(Date.now() + 60*60*1000).toISOString(),
  endTime: new Date(Date.now() + 120*60*1000).toISOString()
});

const req = http.request({
  hostname: '127.0.0.1',
  port: 5000,
  path: '/api/reservation',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
}, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => console.log('Response:', res.statusCode, body));
});

req.on('error', (e) => {
  console.error(`Problem with request: ${e.message}`);
});

req.write(data);
req.end();
