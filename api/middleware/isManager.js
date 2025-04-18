const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

exports.isManager = async (req, res, next) => {
  try {
    if (!req.user || !req.user.id) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { role: true }
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.role.toUpperCase() !== 'MANAGER') {
        return res.status(403).json({ error: 'Manager access required' });
      }
      

    next();
  } catch (error) {
    console.error('Error in isManager middleware:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}; 