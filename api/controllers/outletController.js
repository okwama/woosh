const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all outlets
const getOutlets = async (req, res) => {
  try {
    const outlets = await prisma.outlet.findMany({
      select: {
        id: true,
        name: true,
        address: true,
      },
    });
    res.json(outlets);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch outlets' });
  }
};

// Create a new outlet
const createOutlet = async (req, res) => {
  const { name, address } = req.body;

  try {
    const outlet = await prisma.outlet.create({
      data: {
        name,
        address,
      },
    });
    res.status(201).json(outlet);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create outlet' });
  }
};

// Update an outlet
const updateOutlet = async (req, res) => {
  const { id } = req.params;
  const { name, address } = req.body;

  try {
    const updatedOutlet = await prisma.outlet.update({
      where: { id: parseInt(id) },
      data: {
        name,
        address,
      },
    });
    res.json(updatedOutlet);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update outlet' });
  }
};

module.exports = { getOutlets, createOutlet, updateOutlet };
