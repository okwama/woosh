const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all outlets
const getOutlets = async (req, res) => {
  try {
    const outlets = await prisma.outlet.findMany({
      select: {
        id: true,
        name: true,
        balance: true,
        address: true,
        latitude: true,
        longitude: true,
      },
    });
    res.status(200).json(outlets);
  } catch (error) {
    console.error('Error fetching outlets:', error);
    res.status(500).json({ error: 'Failed to fetch outlets' });
  }
};

// Create a new outlet
const createOutlet = async (req, res) => {
  const { name, address, latitude, longitude, balance, email, phone, kraPin } = req.body;

  if (!name || !address) {
    return res.status(400).json({ error: 'Name and address are required' });
  }

  try {
    const newOutlet = await prisma.outlet.create({
      data: {
        name,
        address,
        ...(balance && { balance }),
        ...(email && { email }),
        ...(phone && { phone }),
        ...(kraPin && { kraPin }),
        latitude,
        longitude,
      },
    });
    res.status(201).json(newOutlet);
  } catch (error) {
    console.error('Error creating outlet:', error);
    res.status(500).json({ error: 'Failed to create outlet' });
  }
};

// Update an outlet
const updateOutlet = async (req, res) => {
  const { id } = req.params;
  const { name, address, latitude, longitude, balance, email, phone, kraPin } = req.body;

  if (!name || !address) {
    return res.status(400).json({ error: 'Name and address are required' });
  }

  try {
    const updatedOutlet = await prisma.outlet.update({
      where: { id: parseInt(id) },
      data: {
        name,
        address,
        ...(balance && { balance }),
        ...(email && { email }),
        ...(phone && { phone }),
        ...(kraPin && { kraPin }),
        latitude,
        longitude,
          },
    });
    res.status(200).json(updatedOutlet);
  } catch (error) {
    console.error('Error updating outlet:', error);
    res.status(500).json({ error: 'Failed to update outlet' });
  }
};

// Get products for a specific outlet
const getOutletProducts = async (req, res) => {
  const { id } = req.params;
  
  try {
    const outlet = await prisma.outlet.findUnique({
      where: { id: parseInt(id) },
      include: {
        products: {
          include: {
            product: true
          }
        }
      }
    });
    
    if (!outlet) {
      return res.status(404).json({ error: 'Outlet not found' });
    }
    
    // Format the response to return just the products
    const products = outlet.products.map(op => ({
      ...op.product,
      quantity: op.quantity
    }));
    
    res.status(200).json(products);
  } catch (error) {
    console.error('Error fetching outlet products:', error);
    res.status(500).json({ error: 'Failed to fetch outlet products' });
  }
};

module.exports = {
  getOutlets,
  createOutlet,
  updateOutlet,
  getOutletProducts
};