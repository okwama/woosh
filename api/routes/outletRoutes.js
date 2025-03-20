const express = require('express');
const {  getOutlets,  createOutlet,  updateOutlet,} = require('../controllers/outletController');

const router = express.Router();

// ✅ Fix: Remove the extra "/outlets"
router
  .route('/')
  .get(getOutlets) // GET /api/outlets
  .post(createOutlet); // POST /api/outlets

router
  .route('/:id')
  .put(updateOutlet); // PUT /api/outlets/:id

module.exports = router;
