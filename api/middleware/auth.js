const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

exports.auth = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.header('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token, authorization denied' });
    }

    const token = authHeader.replace('Bearer ', '');

    try {
      // Verify token
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      // Get user from database
      const user = await prisma.user.findUnique({
        where: { id: decoded.userId },
        select: {
          id: true,
          name: true,
          email: true,
          role: true
        }
      });

      if (!user) {
        return res.status(401).json({ error: 'User not found' });
      }

      // Add user to request
      req.user = user;
      next();
    } catch (err) {
      res.status(401).json({ error: 'Token is not valid' });
    }
  } catch (err) {
    console.error('Error in auth middleware:', err);
    res.status(500).json({ error: 'Server Error' });
  }
}; 