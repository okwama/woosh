const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Create a new journey plan
const createJourneyPlan = async (req, res) => {
  const { outletId } = req.body; // Only outletId is required in the request body
  const userId = req.user.id; // Get the authenticated user's ID from the request

  // Validate required fields
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

    // Create the journey plan with auto-generated date and time
    const journeyPlan = await prisma.journeyPlan.create({
      data: {
        date: new Date(), // Auto-generate the current date
        time: new Date(), // Auto-generate the current time
        userId,
        outletId,
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
    });
    res.json(journeyPlans);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch journey plans' });
  }
};

module.exports = { createJourneyPlan, getJourneyPlans };