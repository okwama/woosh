const express = require('express');
const { authenticateToken } = require('../middleware/authMiddleware');
const {
  getProducts,
  createProduct,
  updateProduct,
  deleteProduct,
} = require('../controllers/productController');

const router = express.Router();

// Protect all routes with authentication middleware
router.use(authenticateToken);

/**
 * @route   GET /api/products
 * @desc    Get all products
 * @access  Private
 * @query   {
 *   page?: number - Page number for pagination (default: 1)
 *   limit?: number - Number of items per page (default: 10)
 * }
 */
router.get('/', getProducts);

/**
 * @route   POST /api/products
 * @desc    Create a new product
 * @access  Private
 * @body    {
 *   name: string (required)
 *   description?: string
 *   price: number (required)
 *   currentStock?: number (default: 0)
 *   reorderPoint?: number (default: 0)
 *   orderQuantity?: number (default: 0)
 *   outletId: number (required)
 * }
 */
router.post('/', createProduct);

/**
 * @route   PUT /api/products/:id
 * @desc    Update a product
 * @access  Private
 * @params  {
 *   id: number (required) - Product ID
 * }
 * @body    {
 *   name?: string
 *   description?: string
 *   price?: number
 *   currentStock?: number
 *   reorderPoint?: number
 *   orderQuantity?: number
 * }
 */
router.put('/:id', updateProduct);

/**
 * @route   DELETE /api/products/:id
 * @desc    Delete a product
 * @access  Private
 * @params  {
 *   id: number (required) - Product ID
 * }
 */
router.delete('/:id', deleteProduct);

module.exports = router; 