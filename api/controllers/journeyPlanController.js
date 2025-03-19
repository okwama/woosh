const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Ensure userId is not null
const getUserId = (req) => {
  const userId = req.user?.id;
  if (!userId) {
    throw new Error('User ID is required');
  }
  return userId;
};

// Create a new journey plan
const createJourneyPlan = async (req, res) => {
  const { outletId } = req.body;
  const userId = req.user.id;

  // Input validation
  if (!outletId) {
    return res.status(400).json({ error: 'Missing required field: outletId' });
  }

  try {
    // Check if the outlet exists
    const outlet = await prisma.outlet.findUnique({
      where: { id: outletId },
    });

    if (!outlet) {
      return res.status(404).json({ error: 'Outlet not found' });
    }

    // Create the journey plan
    const journeyPlan = await prisma.journeyPlan.create({
      data: {
        date: new Date(), // Use current date
        time: new Date(), // Use current time
        userId,
        outletId,
        status: 'pending', // Default status
      },
      include: {
        outlet: true, // Include the outlet data in the response
      },
    });

    res.status(201).json(journeyPlan);
  } catch (error) {
    console.error('Error creating journey plan:', error);
    res.status(500).json({ error: 'Failed to create journey plan' });
  }
};

// Get all journey plans for the authenticated user with outlet details
const getJourneyPlans = async (req, res) => {
  const userId = req.user.id;
  const { page = 1, limit = 10 } = req.query; // Pagination parameters

  try {
    const journeyPlans = await prisma.journeyPlan.findMany({
      where: { userId },
      include: {
        outlet: {
          select: {
            id: true,
            name: true,
            address: true,
          },
        },
      },
      skip: (page - 1) * limit, // Pagination: skip records
      take: parseInt(limit), // Pagination: limit records
    });

    // Get total count of journey plans for pagination metadata
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
        totalPages: Math.ceil(totalJourneyPlans / limit),
      },
    });
  } catch (error) {
    console.error('Error fetching journey plans:', error);
    res.status(500).json({ error: 'Failed to fetch journey plans' });
  }
};

// Update a journey plan
const updateJourneyPlan = async (req, res) => {
  const { journeyId } = req.params;
  const { status, checkInTime, latitude, longitude, imageUrl } = req.body;
  const userId = req.user.id;

  // Input validation
  if (!journeyId) {
    return res.status(400).json({ error: 'Missing required field: journeyId' });
  }

  // Validate status
  const validStatuses = ['pending', 'checked_in', 'completed'];
  if (status && !validStatuses.includes(status)) {
    return res.status(400).json({ error: 'Invalid status value' });
  }

  try {
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

    // Update the journey plan
    const updatedJourneyPlan = await prisma.journeyPlan.update({
      where: { id: parseInt(journeyId) },
      data: {
        status: status || existingJourneyPlan.status,
        checkInTime: checkInTime ? new Date(checkInTime) : existingJourneyPlan.checkInTime,
        latitude: latitude || existingJourneyPlan.latitude,
        longitude: longitude || existingJourneyPlan.longitude,
        imageUrl: imageUrl || existingJourneyPlan.imageUrl,
      },
      include: {
        outlet: true, // Include the outlet data in the response
      },
    });

    res.json(updatedJourneyPlan);
  } catch (error) {
    console.error('Error updating journey plan:', error);
    res.status(500).json({ error: 'Failed to update journey plan' });
  }
};

module.exports = { createJourneyPlan, getJourneyPlans, updateJourneyPlan };