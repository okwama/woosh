const express = require('express');
const { getOutlets, createOutlet, updateOutlet, getOutletProducts } = require('../controllers/outletController');
const { authenticateToken } = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authenticateToken); // Add authentication middleware to all outlet routes

// ✅ Fix: Remove the extra "/outlets"
router
  .route('/')
  .get(getOutlets) // GET /api/outlets
  .post(createOutlet); // POST /api/outlets

router
  .route('/:id')
  .put(updateOutlet); // PUT /api/outlets/:id

router
  .route('/:id/products')
  .get(getOutletProducts); // GET /api/outlets/:id/products

module.exports = router;
