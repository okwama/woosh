require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const authRoutes = require('./routes/authRoutes');
const orderRoutes = require('./routes/orderRoutes');
const journeyPlanRoutes = require('./routes/journeyPlanRoutes');
const outletRoutes = require('./routes/outletRoutes');
const noticeBoardRoutes = require('./routes/noticeBoardRoutes');
const productRoutes = require('./routes/productRoutes');
const reportRoutes = require('./routes/reportRoutes');
const leaveRoutes = require('./routes/leave.routes');

const app = express();
app.use(express.json());
app.use(cors());
app.use(morgan('dev'));

// Default Route
app.get('/', (req, res) => res.json({ message: 'Welcome to the API' }));

// Route Prefixing
app.use('/api/auth', authRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/journey-plans', journeyPlanRoutes);
app.use('/api/outlets', outletRoutes);
app.use('/api/notice-board', noticeBoardRoutes);
app.use('/api/products', productRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/leave', leaveRoutes);

// Handle 404 Errors
app.use((req, res, next) => {
  const error = new Error('Not found');
  error.status = 404;
  next(error);
});

// Error Handling Middleware
app.use((error, req, res, next) => {
  res.status(error.status || 500).json({ error: { message: error.message } });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, '0.0.0.0', () => console.log(`🚀 Server running on port ${PORT}`));

// Graceful Shutdown
process.on('SIGINT', () => {
  console.log('Shutting down server...');
  process.exit();
});
