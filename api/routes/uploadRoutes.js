const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/authMiddleware');
const { uploadImage } = require('../controllers/uploadController');

// Protect all routes with authentication middleware
router.use(authenticateToken);

// Image upload route
router.post('/upload-image', uploadImage);

module.exports = router; 