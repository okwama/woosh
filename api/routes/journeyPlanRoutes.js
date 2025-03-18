const express = require('express');
const authMiddleware = require('../middleware/authMiddleware');
const { createJourneyPlan, getJourneyPlans } = require('../controllers/journeyPlanController');

const router = express.Router();

// Protect all routes with authentication middleware
router.use(authMiddleware);

// Create a journey plan
router.post('/journey-plans', createJourneyPlan);

// Get all journey plans for the authenticated user
router.get('/journey-plans', getJourneyPlans);

module.exports = router;