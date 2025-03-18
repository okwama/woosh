const express = require('express');
const authMiddleware = require('../middleware/authMiddleware');
const { createOrder, getOrders, updateOrder } = require('../controllers/orderController');

const router = express.Router();

router.use(authMiddleware);

router.post('/orders', createOrder);
router.get('/orders', getOrders);
router.put('/orders/:id', updateOrder);

module.exports = router;