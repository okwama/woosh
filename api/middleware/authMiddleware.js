const jwt = require('jsonwebtoken');
const { getPrismaClient } = require('../lib/prisma');
const prisma = getPrismaClient();

const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'Access token required' });
    }

    // Verify the token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Check if token exists in database
    const tokenRecord = await prisma.token.findFirst({
      where: {
        token: token,
        salesRepId: decoded.userId,
        expiresAt: {
          gt: new Date()
        }
      }
    });

    if (!tokenRecord) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    // Get user details
    const user = await prisma.salesRep.findUnique({
      where: { id: decoded.userId },
      include: {
        Manager: true
      }
    });

    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = user;
    req.token = token;
    next();
  } catch (error) {
    console.error('Authentication error:', error);
    return res.status(401).json({ error: 'Invalid token' });
  }
};

module.exports = { authenticateToken };