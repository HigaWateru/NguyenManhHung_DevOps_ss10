const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    status: 'success',
    message: 'Backend API in Custom Bridge Network',
    db_config: {
      host: process.env.DB_HOST || 'db-server',
      port: process.env.DB_PORT || 5432,
      database: process.env.DB_NAME || 'mydb',
      user: process.env.DB_USER || 'myuser'
    }
  });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
