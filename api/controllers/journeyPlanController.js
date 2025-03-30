const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Ensure userId is not null
const getUserId = (req) => {
  if (!req.user || !req.user.id) {
    throw new Error('User authentication required');
  }
  return req.user.id;
};

// Create a new journey plan
const createJourneyPlan = async (req, res) => {
  try {
    const { outletId, date, notes } = req.body;
    const userId = req.user.id;

    console.log('Creating journey plan with:', { outletId, date, userId, notes });

    // Input validation
    if (!outletId) {
      return res.status(400).json({ error: 'Missing required field: outletId' });
    }

    if (!date) {
      return res.status(400).json({ error: 'Missing required field: date' });
    }

    // Check if the outlet exists
    const outlet = await prisma.outlet.findUnique({
      where: { id: parseInt(outletId) },
    });

    if (!outlet) {
      return res.status(404).json({ error: 'Outlet not found' });
    }

    // Parse the date from ISO string
    let journeyDate;
    try {
      journeyDate = new Date(date);
      if (isNaN(journeyDate.getTime())) {
        return res.status(400).json({ error: 'Invalid date format' });
      }
    } catch (error) {
      console.error('Date parsing error:', error);
      return res.status(400).json({ error: 'Invalid date format' });
    }

    // Validate that the date is not in the past
    const now = new Date();
    now.setHours(0, 0, 0, 0); // Set to start of day for comparison
    if (journeyDate < now) {
      return res.status(400).json({ error: 'Journey date cannot be in the past' });
    }

    // Extract time from the date in HH:MM format
    const time = journeyDate.toLocaleTimeString('en-US', {
      hour12: false,
      hour: '2-digit',
      minute: '2-digit'
    });

    // Create the journey plan
    const journeyPlan = await prisma.journeyPlan.create({
      data: {
        date: journeyDate,
        time: time,
        userId: userId,
        outletId: parseInt(outletId),
        status: 0, // 0 for pending
        notes: notes,
      },
      include: {
        outlet: true,
      },
    });

    console.log('Journey plan created successfully:', journeyPlan);
    res.status(201).json(journeyPlan);
  } catch (error) {
    console.error('Error creating journey plan:', error);
    res.status(500).json({ 
      error: 'Failed to create journey plan',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Get all journey plans for the authenticated user with outlet details
const getJourneyPlans = async (req, res) => {
  try {
    const userId = getUserId(req);
    const { page = 1, limit = 10 } = req.query;

    const journeyPlans = await prisma.journeyPlan.findMany({
      where: { userId },
      include: {
        outlet: true,
      },
      orderBy: {
        date: 'desc'
      },
      skip: (parseInt(page) - 1) * parseInt(limit),
      take: parseInt(limit),
    });

    const totalJourneyPlans = await prisma.journeyPlan.count({
      where: { userId },
    });

    res.status(200).json({
      success: true,
      data: journeyPlans,
      pagination: {
        total: totalJourneyPlans,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(totalJourneyPlans / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error fetching journey plans:', error);
    
    if (error.message === 'User authentication required') {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    res.status(500).json({ 
      error: 'Failed to fetch journey plans',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Update a journey plan
const updateJourneyPlan = async (req, res) => {
  const { journeyId } = req.params;
  const { 
    outletId, 
    status, 
    checkInTime, 
    latitude, 
    longitude, 
    imageUrl, 
    notes,
    checkoutTime,
    checkoutLatitude,
    checkoutLongitude 
  } = req.body;

  // Log request details for debugging
  console.log('[CHECKOUT LOG] Updating journey plan:', { 
    journeyId, outletId, status, checkInTime, 
    latitude, longitude, imageUrl, notes,
    checkoutTime, checkoutLatitude, checkoutLongitude
  });

  try {
    // Validate required params
    if (!journeyId) {
      return res.status(400).json({ error: 'Missing required field: journeyId' });
    }

    // Get the authenticated user
    const userId = req.user.id;

    // Status mapping
    const STATUS_MAP = {
      'pending': 0,
      'checked_in': 1,
      'in_progress': 2,
      'completed': 3,
      'cancelled': 4
    };

    const REVERSE_STATUS_MAP = {
      0: 'pending',
      1: 'checked_in',
      2: 'in_progress',
      3: 'completed',
      4: 'cancelled'
    };

    // Check if the journey plan exists and belongs to the user
    const existingJourneyPlan = await prisma.journeyPlan.findUnique({
      where: { id: parseInt(journeyId) },
    });

    if (!existingJourneyPlan) {
      return res.status(404).json({ error: 'Journey plan not found' });
    }

    if (existingJourneyPlan.userId !== userId) {
      return res.status(403).json({ error: 'Unauthorized to update this journey plan' });
    }

    // Add validation for status transitions if needed
    const currentStatus = REVERSE_STATUS_MAP[existingJourneyPlan.status];
    
    // Log status change if applicable
    if (status) {
      console.log(`[CHECKOUT LOG] Status changing from ${currentStatus} to ${status}`);
    }
    
    // Log checkout data if provided
    if (checkoutTime) {
      console.log('[CHECKOUT LOG] Checkout data received:');
      console.log(`[CHECKOUT LOG] Checkout Time: ${checkoutTime}`);
      console.log(`[CHECKOUT LOG] Checkout Latitude: ${checkoutLatitude}`);
      console.log(`[CHECKOUT LOG] Checkout Longitude: ${checkoutLongitude}`);
    }

    // Validate if outlet exists
    if (outletId) {
      const outlet = await prisma.outlet.findUnique({
        where: { id: parseInt(outletId) },
      });

      if (!outlet) {
        return res.status(400).json({ error: 'Outlet not found' });
      }
    }

    // Update the journey plan
    const updatedJourneyPlan = await prisma.journeyPlan.update({
      where: { id: parseInt(journeyId) },
      data: {
        status: status ? STATUS_MAP[status] : existingJourneyPlan.status,
        checkInTime: checkInTime ? new Date(checkInTime) : existingJourneyPlan.checkInTime,
        latitude: latitude || existingJourneyPlan.latitude,
        longitude: longitude || existingJourneyPlan.longitude,
        imageUrl: imageUrl || existingJourneyPlan.imageUrl,
        notes: notes !== undefined ? notes : existingJourneyPlan.notes,
        checkoutTime: checkoutTime ? new Date(checkoutTime) : existingJourneyPlan.checkoutTime,
        checkoutLatitude: checkoutLatitude || existingJourneyPlan.checkoutLatitude,
        checkoutLongitude: checkoutLongitude || existingJourneyPlan.checkoutLongitude,
        outlet: outletId
          ? {
              connect: { id: parseInt(outletId) },
            }
          : undefined,
      },
      include: {
        outlet: true,
      },
    });

    // Log the updated journey plan
    console.log('[CHECKOUT LOG] Journey plan updated successfully:');
    console.log(`[CHECKOUT LOG] ID: ${updatedJourneyPlan.id}`);
    console.log(`[CHECKOUT LOG] Status: ${REVERSE_STATUS_MAP[updatedJourneyPlan.status]}`);
    console.log(`[CHECKOUT LOG] Checkout Time: ${updatedJourneyPlan.checkoutTime}`);
    console.log(`[CHECKOUT LOG] Checkout Latitude: ${updatedJourneyPlan.checkoutLatitude}`);
    console.log(`[CHECKOUT LOG] Checkout Longitude: ${updatedJourneyPlan.checkoutLongitude}`);

    res.status(200).json({
      ...updatedJourneyPlan,
      status: REVERSE_STATUS_MAP[updatedJourneyPlan.status]
    });
  } catch (error) {
    // Handle errors
    console.error('[CHECKOUT LOG] Error updating journey plan:', error);
    res.status(500).json({ error: 'Failed to update journey plan' });
  }
};

module.exports = { createJourneyPlan, getJourneyPlans, updateJourneyPlan };