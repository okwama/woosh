const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Create a new journey plan
const createJourneyPlan = async (req, res) => {
  const { outletId } = req.body;
  const userId = req.user.id;

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
        date: new Date(),
        time: new Date(),
        userId,
        outletId,
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