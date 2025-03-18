const express = require('express');
const { getOutlets, createOutlet, updateOutlet } = require('../controllers/outletController');

const router = express.Router();


// Get all outlets
router.get('/outlets', getOutlets);

// Create a new outlet
router.post('/outlets', createOutlet);

// Update an outlet
router.put('/outlets/:id', updateOutlet);

module.exports = router;