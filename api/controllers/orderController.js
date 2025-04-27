const { getPrismaClient } = require('../lib/prisma');
const prisma = getPrismaClient();

// Create order with order items
const createOrder = async (req, res) => {
  console.log('=== Create Order Request ===');
  console.log('Request Body:', {
    clientId: req.body.clientId,
    orderItems: req.body.orderItems,
    comment: req.body.comment,
    customerType: req.body.customerType,
    customerId: req.body.customerId,
    customerName: req.body.customerName
  });
  console.log('User:', req.user);

  const { clientId, orderItems } = req.body;
  const salesRepId = req.user.id;

  try {
    // Validate required fields
    if (!clientId || !orderItems || orderItems.length === 0) {
      console.log('Validation failed:', { 
        hasClientId: !!clientId, 
        hasOrderItems: !!orderItems, 
        orderItemsLength: orderItems?.length 
      });
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: clientId and orderItems are required',
      });
    }

    // Validate client exists
    console.log('Validating client:', clientId);
    const client = await prisma.clients.findUnique({
      where: { id: clientId },
    });

    if (!client) {
      console.log('Client not found:', clientId);
      return res.status(404).json({
        success: false,
        error: 'Client not found',
      });
    }
    console.log('Client found:', client.name);
    
    // Get client type and map to a customer type string
    let customerType = "BUSINESS"; // Default
    if (client.client_type !== null && client.client_type !== undefined) {
      // Convert numeric client_type to string customer type
      // You can adjust the mapping based on your business logic
      switch (client.client_type) {
        case 1:
          customerType = "RETAIL";
          break;
        case 2:
          customerType = "WHOLESALE";
          break;
        case 3:
          customerType = "DISTRIBUTOR";
          break;
        default:
          customerType = "BUSINESS";
      }
      console.log(`Using client_type ${client.client_type} mapped to customerType: ${customerType}`);
    } else {
      console.log('Client has no client_type, using default: BUSINESS');
    }

    // Validate products exist and have sufficient stock
    for (const item of orderItems) {
      console.log('Validating order item:', item);
      
      if (!item.productId || !item.quantity) {
        console.log('Invalid order item:', item);
        return res.status(400).json({
          success: false,
          error: 'Each order item must have productId and quantity',
        });
      }

      // Get product with its price options through category
      console.log('Fetching product:', item.productId);
      const product = await prisma.product.findUnique({
        where: { id: item.productId },
        include: {
          client: true
        }
      });

      if (!product) {
        console.log('Product not found:', item.productId);
        return res.status(404).json({
          success: false,
          error: `Product with ID ${item.productId} not found`,
        });
      }
      console.log('Product found:', product.name);

      // If price option is provided, validate it
      if (item.priceOptionId) {
        console.log('Validating price option:', item.priceOptionId);
        // Get price options for this product's category
        const categoryWithPriceOptions = await prisma.category.findUnique({
          where: { id: product.category_id },
          include: {
            priceOptions: true
          }
        });

        if (!categoryWithPriceOptions) {
          console.log('Category not found for product:', product.name);
          return res.status(404).json({
            success: false,
            error: `Category not found for product ${product.name}`,
          });
        }
        console.log('Category found:', categoryWithPriceOptions.id);

        const priceOption = categoryWithPriceOptions.priceOptions.find(
          po => po.id === item.priceOptionId
        );

        if (!priceOption) {
          console.log('Price option not found:', item.priceOptionId);
          return res.status(404).json({
            success: false,
            error: `Price option with ID ${item.priceOptionId} not found for product ${product.name}`,
          });
        }
        console.log('Price option found:', priceOption.id);
      }

      if (product.currentStock < item.quantity) {
        console.log('Insufficient stock:', {
          product: product.name,
          requested: item.quantity,
          available: product.currentStock
        });
        return res.status(400).json({
          success: false,
          error: `Insufficient stock for product ${product.name}`,
        });
      }
    }

    // Create new order (outside of transaction)
    console.log('Creating order outside of transaction');
    const newOrder = await prisma.myOrder.create({
      data: {
        totalAmount: 0, // Will update later
        comment: req.body.comment || "",
        customerType: customerType, // Use derived customer type instead of default
        customerId: req.body.customerId || "",
        customerName: req.body.customerName || client.name,
        user: {
          connect: { id: salesRepId }
        },
        client: {
          connect: { id: clientId }
        }
      }
    });

    console.log('Created new order:', { 
      orderId: newOrder.id, 
      clientId: newOrder.clientId,
      userId: newOrder.userId,
      customerType: newOrder.customerType
    });

    // Create order items separately
    let totalAmount = 0;
    const createdOrderItems = [];
    
    for (const item of orderItems) {
      console.log('Processing order item:', {
        productId: item.productId,
        quantity: item.quantity,
        priceOptionId: item.priceOptionId
      });

      // Get product and its price options to calculate price
      const product = await prisma.product.findUnique({
        where: { id: item.productId }
      });

      if (!product) {
        console.error(`Product with ID ${item.productId} not found during order item creation`);
        continue; // Skip this item and try to process other items
      }

      // Safely access category_id with null check
      if (!product.category_id) {
        console.error(`Product ${product.name} (ID: ${product.id}) has no category_id`);
        continue;
      }

      const categoryWithPriceOptions = await prisma.category.findUnique({
        where: { id: product.category_id },
        include: {
          priceOptions: true
        }
      });

      // Safely handle missing category or price options
      if (!categoryWithPriceOptions) {
        console.error(`Category with ID ${product.category_id} not found`);
        continue;
      }

      let itemPrice = 0;
      if (item.priceOptionId) {
        const priceOption = categoryWithPriceOptions.priceOptions?.find(
          po => po?.id === item.priceOptionId
        );
        
        if (!priceOption) {
          console.error(`Price option with ID ${item.priceOptionId} not found in category ${categoryWithPriceOptions.id}`);
          continue;
        }
        
        itemPrice = priceOption.value || 0;
        console.log('Price option found:', {
          priceOptionId: priceOption.id,
          value: priceOption.value
        });
      }

      try {
        // First create order item with basic fields
        console.log('Creating order item with basic fields');
        const orderItemData = {
          quantity: item.quantity,
          orderId: newOrder.id,
          productId: item.productId
        };
        
        console.log('Order item data:', orderItemData);
        const orderItem = await prisma.orderItem.create({
          data: orderItemData
        });
        
        console.log('Created order item:', orderItem);
        
        // Then, if needed, update with price option
        if (item.priceOptionId) {
          try {
            console.log('Adding price option in separate operation');
            // Try using raw SQL if Prisma relations are causing issues
            const result = await prisma.$executeRaw`
              UPDATE OrderItem 
              SET priceOptionId = ${item.priceOptionId} 
              WHERE id = ${orderItem.id}
            `;
            console.log('Price option update result:', result);
          } catch (priceOptionError) {
            console.error('Error updating price option:', priceOptionError);
            // Continue without price option if this fails
          }
        }
        
        createdOrderItems.push(orderItem);
        totalAmount += itemPrice * item.quantity;
        
        // Update stock
        try {
          await prisma.product.update({
            where: { id: item.productId },
            data: {
              currentStock: {
                decrement: item.quantity
              }
            }
          });
        } catch (stockError) {
          console.error('Error updating product stock:', stockError);
          // Continue even if stock update fails
        }
      } catch (error) {
        console.error('Error creating order item:', error);
        // Continue with next item even if this one fails
      }
    }
    
    // If no order items were created successfully, return an error
    if (createdOrderItems.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Failed to create any order items'
      });
    }
    
    // Update order with final amount
    console.log('Updating order with final amount:', totalAmount);
    try {
      const updatedOrder = await prisma.myOrder.update({
        where: { id: newOrder.id },
        data: {
          totalAmount: parseFloat((totalAmount || 0).toFixed(2))
        },
        include: {
          orderItems: {
            include: {
              product: true,
              priceOption: true
            }
          },
          client: true,
          user: {
            select: {
              id: true,
              name: true,
              phoneNumber: true
            }
          }
        }
      });

      console.log('Order creation complete');
      res.status(201).json({
        success: true,
        data: updatedOrder
      });
    } catch (finalUpdateError) {
      console.error('Error updating order with final amount:', finalUpdateError);
      // Return partial success since we did create the order and some items
      res.status(201).json({
        success: true,
        data: {
          id: newOrder.id,
          message: 'Order created but final update failed'
        },
        warning: 'Order total could not be updated'
      });
    }

  } catch (error) {
    console.error('Error creating order:', error);
    if (error.code === 'P2003') {
      res.status(400).json({
        success: false,
        error: 'Invalid product or client reference'
      });
    } else {
      console.error('Detailed error:', {
        name: error.name,
        message: error.message,
        code: error.code,
        meta: error.meta,
        stack: error.stack
      });
      res.status(500).json({
        success: false,
        error: 'Failed to create order'
      });
    }
  }
};

// Optimized order creation function (does not replace existing createOrder)
const createOrderOptimized = async (req, res) => {
  console.log('=== [Optimized] Create Order Request ===');
  const { clientId, orderItems } = req.body;
  const salesRepId = req.user.id;

  try {
    // Validate required fields
    if (!clientId || !orderItems || orderItems.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: clientId and orderItems are required',
      });
    }

    // Validate client exists
    const client = await prisma.clients.findUnique({ where: { id: clientId } });
    if (!client) {
      return res.status(404).json({
        success: false,
        error: 'Client not found',
      });
    }

    // Map client_type to customerType
    let customerType = "BUSINESS";
    switch (client.client_type) {
      case 1:
        customerType = "RETAIL";
        break;
      case 2:
        customerType = "WHOLESALE";
        break;
      case 3:
        customerType = "DISTRIBUTOR";
        break;
      default:
        customerType = "BUSINESS";
    }

    // Gather all productIds and priceOptionIds
    const productIds = orderItems.map(item => item.productId);
    const priceOptionIds = orderItems.map(item => item.priceOptionId).filter(Boolean);

    // Batch fetch products
    const products = await prisma.product.findMany({
      where: { id: { in: productIds } }
    });
    const productsById = Object.fromEntries(products.map(p => [p.id, p]));

    // Batch fetch categories (with priceOptions)
    const categoryIds = [...new Set(products.map(p => p.category_id).filter(Boolean))];
    const categories = await prisma.category.findMany({
      where: { id: { in: categoryIds } },
      include: { priceOptions: true }
    });
    const categoriesById = Object.fromEntries(categories.map(c => [c.id, c]));

    // Validate and prepare order items
    let totalAmount = 0;
    const orderItemsData = [];
    for (const item of orderItems) {
      if (!item.productId || !item.quantity) {
        return res.status(400).json({
          success: false,
          error: 'Each order item must have productId and quantity',
        });
      }
      const product = productsById[item.productId];
      if (!product) {
        return res.status(404).json({
          success: false,
          error: `Product with ID ${item.productId} not found`,
        });
      }
      if (product.currentStock < item.quantity) {
        return res.status(400).json({
          success: false,
          error: `Insufficient stock for product ${product.name}`,
        });
      }
      let itemPrice = 0;
      let priceOptionId = null;
      if (item.priceOptionId) {
        const category = categoriesById[product.category_id];
        if (!category) {
          return res.status(404).json({
            success: false,
            error: `Category not found for product ${product.name}`,
          });
        }
        const priceOption = category.priceOptions.find(po => po.id === item.priceOptionId);
        if (!priceOption) {
          return res.status(404).json({
            success: false,
            error: `Price option with ID ${item.priceOptionId} not found for product ${product.name}`,
          });
        }
        itemPrice = priceOption.value || 0;
        priceOptionId = priceOption.id;
      }
      // Calculate total amount (if you want to sum prices)
      totalAmount += itemPrice * item.quantity;
      orderItemsData.push({
        quantity: item.quantity,
        productId: item.productId,
        priceOptionId: priceOptionId,
        // Add other fields as needed
      });
    }

    // Transaction: create order and items
    const [newOrder] = await prisma.$transaction([
      prisma.myOrder.create({
        data: {
          totalAmount: totalAmount, // Set computed total
          comment: req.body.comment || "",
          customerType: customerType,
          customerId: req.body.customerId || "",
          customerName: req.body.customerName || client.name,
          user: { connect: { id: salesRepId } },
          client: { connect: { id: clientId } },
        }
      })
    ]);

    // Add orderId to each item
    const orderItemsWithOrderId = orderItemsData.map(item => ({ ...item, orderId: newOrder.id }));

    // Batch create order items
    await prisma.orderItem.createMany({ data: orderItemsWithOrderId });

    // Optionally, update stock for each product (if needed)
    // await Promise.all(orderItems.map(item =>
    //   prisma.product.update({
    //     where: { id: item.productId },
    //     data: { currentStock: { decrement: item.quantity } }
    //   })
    // ));

    return res.status(201).json({
      success: true,
      order: newOrder,
      orderItems: orderItemsWithOrderId
    });
  } catch (error) {
    console.error('[Optimized] Error creating order:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to create order (optimized)',
    });
  }
};

// Get orders with pagination
const getOrders = async (req, res) => {
  const salesRepId = req.user.id;
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  const skip = (page - 1) * limit;

  try {
    // Get total count for pagination
    const total = await prisma.myOrder.count({
      where: { userId: salesRepId },
    });

    // Get orders with pagination and order items
    const orders = await prisma.myOrder.findMany({
      where: { userId: salesRepId },
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
        client: true,
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
  const salesRepId = req.user.id;

  try {
    // Validate the order exists and belongs to the sales rep
    const existingOrder = await prisma.myOrder.findFirst({
      where: {
        id: parseInt(id),
        userId: salesRepId,
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
        const newOrderItem = await prisma.orderItem.create({
          data: {
            productId: item.productId,
            quantity: item.quantity,
          },
        });
        
        // Connect the new order item to the order
        await prisma.myOrder.update({
          where: { id: existingOrder.id },
          data: {
            orderItems: {
              connect: { id: newOrderItem.id }
            }
          }
        });
      }
    }

    const updatedOrder = await prisma.myOrder.findUnique({
      where: { id: existingOrder.id },
      include: {
        orderItems: {
          include: {
            product: true,
          },
        },
        client: true,
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
  try {
    const orderId = parseInt(req.params.id);
    const salesRepId = req.user.id;

    console.log(`[DELETE] Processing request - Order: ${orderId}, SalesRep: ${salesRepId}`);

    if (isNaN(orderId)) {
      console.log('[ERROR] Invalid order ID format');
      return res.status(400).json({
        success: false,
        error: 'Invalid order ID format'
      });
    }

    // First find the order with a single query including relations
    const existingOrder = await prisma.myOrder.findFirst({
      where: {
        id: orderId,
        userId: salesRepId,
      },
      include: {
        orderItems: true
      }
    });

    if (!existingOrder) {
      console.log(`[ERROR] Order ${orderId} not found or not owned by sales rep ${salesRepId}`);
      return res.status(404).json({
        success: false,
        error: 'Order not found'
      });
    }

    // Delete order in a transaction to ensure consistency
    await prisma.$transaction(async (tx) => {
      // Delete order items first by disconnecting them
      if (existingOrder.orderItems.length > 0) {
        await tx.myOrder.update({
          where: { id: orderId },
          data: {
            orderItems: {
              disconnect: existingOrder.orderItems.map(item => ({ id: item.id }))
            }
          }
        });
      }

      // Then delete the order
      await tx.myOrder.delete({
        where: { id: orderId }
      });
    });

    console.log(`[SUCCESS] Order ${orderId} deleted successfully`);
    return res.status(200).json({
      success: true,
      message: 'Order deleted successfully'
    });

  } catch (error) {
    console.error('[ERROR] Failed to delete order:', error);
    return res.status(500).json({
      success: false,
      error: 'Failed to delete order'
    });
  }
};

module.exports = { 
  createOrder, 
  getOrders, 
  updateOrder, 
  deleteOrder, 
  createOrderOptimized 
};
