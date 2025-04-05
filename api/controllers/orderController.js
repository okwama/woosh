const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Create order with order items
const createOrder = async (req, res) => {
  console.log('Request Body:', req.body); // Log the request body here

  const { outletId, orderItems } = req.body;
  const userId = req.user.id;

  try {
    // Validate required fields
    if (!outletId || !orderItems || orderItems.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: outletId and orderItems are required',
      });
    }

    // Ensure each order item has productId and quantity
    for (const item of orderItems) {
      if (!item.productId || !item.quantity) {
        return res.status(400).json({
          success: false,
          error: 'Each order item must have productId and quantity',
        });
      }
    }

    // Create order with order items
    const order = await prisma.order.create({
      data: {
        userId,
        outletId,
        orderItems: {
          create: orderItems.map(item => ({
            productId: item.productId,
            quantity: item.quantity,
          })),
        },
      },
      include: {
        orderItems: {
          include: {
            product: true,
          },
        },
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
      error: 'Failed to create order',
    });
  }
};

// Get orders with pagination
const getOrders = async (req, res) => {
  const userId = req.user.id;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const skip = (page - 1) * limit;

  try {
    // Get total count for pagination
    const total = await prisma.order.count({
      where: { userId },
    });

    // Get orders with pagination and order items
    const orders = await prisma.order.findMany({
      where: { userId },
      skip,
      take: limit,
      orderBy: {
        createdAt: 'desc',
      },
      include: {
        orderItems: {
          include: {
            product: true,
          },
        },
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
      totalPages,
    });
  } catch (error) {
    console.error('Error fetching orders:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch orders',
    });
  }
};

// Update order (updating order items)
const updateOrder = async (req, res) => {
  const { id } = req.params;
  const { orderItems } = req.body;
  const userId = req.user.id;

  try {
    // Validate the order exists and belongs to the user
    const existingOrder = await prisma.order.findFirst({
      where: {
        id: parseInt(id),
        userId,
      },
    });

    if (!existingOrder) {
      return res.status(404).json({
        success: false,
        error: 'Order not found or unauthorized',
      });
    }

    // Ensure each order item has productId and quantity
    if (!orderItems || orderItems.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Missing orderItems in the request body',
      });
    }

    for (const item of orderItems) {
      if (!item.productId || !item.quantity) {
        return res.status(400).json({
          success: false,
          error: 'Each order item must have productId and quantity',
        });
      }

      // Check if the order already has an item for the product
      const existingOrderItem = await prisma.orderItem.findFirst({
        where: {
          orderId: existingOrder.id,
          productId: item.productId,
        },
      });

      if (existingOrderItem) {
        // Update the existing order item if it already exists
        await prisma.orderItem.update({
          where: { id: existingOrderItem.id },
          data: { quantity: item.quantity },
        });
      } else {
        // Create a new order item if it doesn't exist
        await prisma.orderItem.create({
          data: {
            orderId: existingOrder.id,
            productId: item.productId,
            quantity: item.quantity,
          },
        });
      }
    }

    const updatedOrder = await prisma.order.findUnique({
      where: { id: existingOrder.id },
      include: {
        orderItems: {
          include: {
            product: true,
          },
        },
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
      error: 'Failed to update order',
    });
  }
};

// Delete order
const deleteOrder = async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;

  try {
    // Validate the order exists and belongs to the user
    const existingOrder = await prisma.order.findFirst({
      where: {
        id: parseInt(id),
        userId,
      },
    });

    if (!existingOrder) {
      return res.status(404).json({
        success: false,
        error: 'Order not found or unauthorized',
      });
    }

    // Delete the order and its associated items
    await prisma.order.delete({
      where: { id: parseInt(id) },
    });

    res.json({
      success: true,
      message: 'Order deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting order:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete order',
    });
  }
};

module.exports = { createOrder, getOrders, updateOrder, deleteOrder };
