const express = require('express');
const { authenticateToken } = require('../middleware/authMiddleware');
const { createOrder, getOrders, updateOrder } = require('../controllers/orderController');

const router = express.Router();

router.use(authenticateToken);

router.post('/', createOrder);
router.get('/', getOrders);
router.put('/:id', updateOrder);

module.exports = router;