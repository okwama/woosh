const { getPrismaClient } = require('../lib/prisma');
const prisma = getPrismaClient();

// Get all outlets
const getOutlets = async (req, res) => {
  try {
    const outlets = await prisma.clients.findMany({
      select: {
        id: true,
        name: true,
        balance: true,
        address: true,
        latitude: true,
        longitude: true,
      },
    });
    
    // Keep balance as a string for client compatibility
    const formattedOutlets = outlets.map(outlet => ({
      ...outlet,
      // No conversion needed - balance remains a string
    }));
    
    res.status(200).json(formattedOutlets);
  } catch (error) {
    console.error('Error fetching outlets:', error);
    res.status(500).json({ error: 'Failed to fetch outlets' });
  }
};

// Create a new outlet
const createOutlet = async (req, res) => {
  const { name, address, latitude, longitude, balance, email, location, tax_pin,contact ,region_id,region,country,client_type} = req.body;

  if (!name || !address) {
    return res.status(400).json({ error: 'Name and address are required' });
  }

  try {
    const newOutlet = await prisma.clients.create({
      data: {
        name,
        address,
        location,
        client_type: 1,
        ...(balance !== undefined && { balance: balance.toString() }),
        ...(email && { email }),
        ...(contact && { contact }),
        ...(tax_pin && { tax_pin }),
        latitude,
        longitude,
        country: {
          connect: { id: parseInt(country) } // Assuming country is the ID
        },
        region,
        region_id: parseInt(region_id),
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
    const updatedOutlet = await prisma.clients.update({
      where: { id: parseInt(id) },
      data: {
        name,
        address,
        ...(balance !== undefined && { balance: balance.toString() }),
        ...(email && { email }),
        ...(contact && { contact }),
        ...(tax_pin && { tax_pin }),
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
    const outlet = await prisma.clients.findUnique({
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

// Get outlet location
const getOutletLocation = async (req, res) => {
  const { id } = req.params;
  
  try {
    const outlet = await prisma.clients.findUnique({
      where: { id: parseInt(id) },
      select: {
        id: true,
        latitude: true,
        longitude: true,
      },
    });
    
    if (!outlet) {
      return res.status(404).json({ error: 'Outlet not found' });
    }
    
    res.status(200).json(outlet);
  } catch (error) {
    console.error('Error fetching outlet location:', error);
    res.status(500).json({ error: 'Failed to fetch outlet location' });
  }
};

module.exports = {
  getOutlets,
  createOutlet,
  updateOutlet,
  getOutletProducts,
  getOutletLocation
};