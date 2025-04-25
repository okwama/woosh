const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Middleware to authenticate the token
exports.auth = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.header('Authorization');
    console.log('Auth Header:', authHeader ? 'Present' : 'Missing');
    
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token, authorization denied' });
    }

    const token = authHeader.replace('Bearer ', '');
    console.log('Token extracted from header');

    try {
      // Verify token
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      console.log('Decoded token:', decoded);
      
      // Get user from database
      const user = await prisma.salesRep.findUnique({
        where: { id: decoded.userId },
        select: {
          id: true,
          name: true,
          email: true,
          role: true
        }
      });

      console.log('User found:', user ? 'Yes' : 'No');

      if (!user) {
        return res.status(401).json({ error: 'User not found' });
      }

      // Add user to request
      req.user = user;
      next();
    } catch (err) {
      console.error('Token verification error:', err);
      res.status(401).json({ error: 'Token is not valid' });
    }
  } catch (err) {
    console.error('Error in auth middleware:', err);
    res.status(500).json({ error: 'Server Error' });
  }
};

// Function to create a manager if the role is 'manager'
const createManagerIfNeeded = async (userId, role, managerDetails) => {
  if (role === 'MANAGER') {
    // Create a new manager record if the role is 'MANAGER'
    try {
      await prisma.manager.create({
        data: {
          userId: userId,
          email: managerDetails.email, // assuming managerDetails includes email
          password: managerDetails.password, // assuming managerDetails includes password
          department: managerDetails.department, // assuming managerDetails includes department
        },
      });
      console.log('Manager created successfully');
    } catch (error) {
      console.error('Error creating manager:', error);
      throw new Error('Failed to create manager');
    }
  }
};

// Function to create a user and update the manager table if necessary
exports.createUser = async (req, res) => {
  const { name, email, phoneNumber, password, role, managerDetails } = req.body;

  try {
    // Create the user first
    const user = await prisma.salesRep.create({
      data: {
        name,
        email,
        phoneNumber,
        password, // Ensure you hash the password before saving it
        role,
      },
    });

    // Call the function to create manager if role is manager
    await createManagerIfNeeded(user.id, role, managerDetails);

    // Respond with the created user
    res.status(201).json(user);
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: 'Failed to create user' });
  }
};
