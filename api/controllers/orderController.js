const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const createOrder = async (req, res) => {
  const { product, quantity } = req.body;
  const userId = req.user.id;

  try {
    const order = await prisma.order.create({
      data: {
        product,
        quantity,
        userId,
      },
    });
    res.json(order);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create order' });
  }
};

const getOrders = async (req, res) => {
  const userId = req.user.id;

  try {
    const orders = await prisma.order.findMany({ where: { userId } });
    res.json(orders);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
};

const updateOrder = async (req, res) => {
  const { id } = req.params;
  const { product, quantity } = req.body;

  try {
    const updatedOrder = await prisma.order.update({
      where: { id: parseInt(id), userId: req.user.id },
      data: { product, quantity },
    });
    res.json(updatedOrder);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update order' });
  }
};

module.exports = { createOrder, getOrders, updateOrder };