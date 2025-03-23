const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Ensure userId is not null
const getUserId = (req) => {
  if (!req.user || !req.user.id) {
    throw new Error('User authentication required');
  }
  return req.user.id;
};

// Get all products
const getProducts = async (req, res) => {
  try {
    const userId = getUserId(req);
    const { page = 1, limit = 10 } = req.query;

    // Get products with pagination
    const products = await prisma.product.findMany({
      include: {
        outlet: true,
      },
      orderBy: {
        name: 'asc',
      },
      skip: (parseInt(page) - 1) * parseInt(limit),
      take: parseInt(limit),
    });

    // Get total count for pagination
    const totalProducts = await prisma.product.count();

    res.status(200).json({
      success: true,
      data: products,
      pagination: {
        total: totalProducts,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(totalProducts / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Error fetching products:', error);
    
    if (error.message === 'User authentication required') {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    res.status(500).json({ 
      error: 'Failed to fetch products',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Create a new product
const createProduct = async (req, res) => {
  try {
    const {
      name,
      description,
      price,
      currentStock,
      reorderPoint,
      orderQuantity,
      outletId,
    } = req.body;
    const userId = getUserId(req);

    // Input validation
    if (!name) {
      return res.status(400).json({ error: 'Missing required field: name' });
    }

    if (!price) {
      return res.status(400).json({ error: 'Missing required field: price' });
    }

    if (!outletId) {
      return res.status(400).json({ error: 'Missing required field: outletId' });
    }

    // Check if outlet exists
    const outlet = await prisma.outlet.findUnique({
      where: { id: parseInt(outletId) },
    });

    if (!outlet) {
      return res.status(404).json({ error: 'Outlet not found' });
    }

    // Create the product
    const product = await prisma.product.create({
      data: {
        name,
        description,
        price: parseFloat(price),
        currentStock: parseInt(currentStock) || 0,
        reorderPoint: parseInt(reorderPoint) || 0,
        orderQuantity: parseInt(orderQuantity) || 0,
        outletId: parseInt(outletId),
      },
      include: {
        outlet: true,
      },
    });

    console.log('Product created successfully:', product);
    res.status(201).json(product);
  } catch (error) {
    console.error('Error creating product:', error);
    
    if (error.message === 'User authentication required') {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    res.status(500).json({ 
      error: 'Failed to create product',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Update a product
const updateProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name,
      description,
      price,
      currentStock,
      reorderPoint,
      orderQuantity,
    } = req.body;
    const userId = getUserId(req);

    // Input validation
    if (!id) {
      return res.status(400).json({ error: 'Missing required field: id' });
    }

    // Check if product exists
    const existingProduct = await prisma.product.findUnique({
      where: { id: parseInt(id) },
    });

    if (!existingProduct) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // Update the product
    const product = await prisma.product.update({
      where: { id: parseInt(id) },
      data: {
        name: name || existingProduct.name,
        description: description || existingProduct.description,
        price: price ? parseFloat(price) : existingProduct.price,
        currentStock: currentStock ? parseInt(currentStock) : existingProduct.currentStock,
        reorderPoint: reorderPoint ? parseInt(reorderPoint) : existingProduct.reorderPoint,
        orderQuantity: orderQuantity ? parseInt(orderQuantity) : existingProduct.orderQuantity,
      },
      include: {
        outlet: true,
      },
    });

    console.log('Product updated successfully:', product);
    res.json(product);
  } catch (error) {
    console.error('Error updating product:', error);
    
    if (error.message === 'User authentication required') {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    res.status(500).json({ 
      error: 'Failed to update product',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

// Delete a product
const deleteProduct = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = getUserId(req);

    // Input validation
    if (!id) {
      return res.status(400).json({ error: 'Missing required field: id' });
    }

    // Check if product exists
    const existingProduct = await prisma.product.findUnique({
      where: { id: parseInt(id) },
    });

    if (!existingProduct) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // Delete the product
    await prisma.product.delete({
      where: { id: parseInt(id) },
    });

    console.log('Product deleted successfully:', id);
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting product:', error);
    
    if (error.message === 'User authentication required') {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    res.status(500).json({ 
      error: 'Failed to delete product',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = {
  getProducts,
  createProduct,
  updateProduct,
  deleteProduct,
}; 