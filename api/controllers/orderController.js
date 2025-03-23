const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const createOrder = async (req, res) => {
  const { outletId, productId, quantity } = req.body;
  const userId = req.user.id;

  try {
    // Validate required fields
    if (!outletId || !productId || !quantity) {
      return res.status(400).json({ 
        success: false,
        error: 'Missing required fields: outletId, productId, and quantity are required' 
      });
    }

    // Create order with relations
    const order = await prisma.order.create({
      data: {
        quantity,
        userId,
        outletId,
        productId,
      },
      include: {
        product: true,
        outlet: true,
        user: {
          select: {
            id: true,
            name: true,
            phoneNumber: true,
          },
        },
      },
    });

    res.status(201).json({
      success: true,
      data: order,
    });
  } catch (error) {
    console.error('Error creating order:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to create order' 
    });
  }
};

const getOrders = async (req, res) => {
  const userId = req.user.id;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const skip = (page - 1) * limit;

  try {
    // Get total count for pagination
    const total = await prisma.order.count({
      where: { userId }
    });

    // Get orders with pagination and relations
    const orders = await prisma.order.findMany({
      where: { userId },
      skip,
      take: limit,
      orderBy: {
        createdAt: 'desc'
      },
      include: {
        product: true,
        outlet: true,
        user: {
          select: {
            id: true,
            name: true,
            phoneNumber: true,
          },
        },
      },
    });

    const totalPages = Math.ceil(total / limit);

    res.json({
      success: true,
      data: orders,
      page,
      limit,
      total,
      totalPages
    });
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch orders' 
    });
  }
};

const updateOrder = async (req, res) => {
  const { id } = req.params;
  const { productId, quantity } = req.body;
  const userId = req.user.id;

  try {
    // Validate the order exists and belongs to the user
    const existingOrder = await prisma.order.findFirst({
      where: { 
        id: parseInt(id),
        userId 
      }
    });

    if (!existingOrder) {
      return res.status(404).json({ 
        success: false,
        error: 'Order not found or unauthorized' 
      });
    }

    // Update order with relations
    const updatedOrder = await prisma.order.update({
      where: { 
        id: parseInt(id)
      },
      data: { 
        productId, 
        quantity 
      },
      include: {
        product: true,
        outlet: true,
        user: {
          select: {
            id: true,
            name: true,
            phoneNumber: true,
          },
        },
      },
    });

    res.json({
      success: true,
      data: updatedOrder,
    });
  } catch (error) {
    console.error('Error updating order:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to update order' 
    });
  }
};

module.exports = { createOrder, getOrders, updateOrder };