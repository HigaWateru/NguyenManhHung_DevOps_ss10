const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

app.get('/', (req, res) => {
  res.json({
    status: 'success',
    message: 'Hello from Multi-service Docker Compose Backend!',
    service: 'backend',
    database_info: {
      host: process.env.DB_HOST || 'database',
      database: process.env.DB_NAME || 'mydb',
      user: process.env.DB_USER || 'myuser'
    }
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, () => {
  console.log(`Backend server listening on port ${PORT}`);
});
