const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/authMiddleware');

// Apply authentication middleware to all check-in routes
router.use(authenticateToken);

// Define your check-in routes here
// For example:
// router.post('/', checkInController.createCheckIn);
// router.get('/', checkInController.getCheckIns);

module.exports = router;
