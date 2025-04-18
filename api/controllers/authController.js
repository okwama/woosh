const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const register = async (req, res) => {
  const { name, email, password, phoneNumber, role, department } = req.body;

  try {
    // Validate required fields
    if (!name || !email || !password || !phoneNumber) {
      return res.status(400).json({ 
        error: 'Registration failed',
        details: 'All fields are required: name, email, password, and phoneNumber'
      });
    }

    // Validate role and convert to uppercase
    const userRole = role ? role.toUpperCase() : 'USER';
    if (!['ADMIN', 'MANAGER', 'USER'].includes(userRole)) {
      return res.status(400).json({
        error: 'Registration failed',
        details: 'Invalid role specified. Must be one of: ADMIN, MANAGER, USER'
      });
    }

    // Validate manager-specific requirements
    if (userRole === 'MANAGER' && !department) {
      return res.status(400).json({
        error: 'Registration failed',
        details: 'Department is required for manager registration'
      });
    }

    // Check if user already exists
    const existingUser = await prisma.user.findFirst({
      where: {
        OR: [
          { email },
          { phoneNumber }
        ]
      }
    });

    if (existingUser) {
      return res.status(400).json({
        error: 'Registration failed',
        details: existingUser.email === email 
          ? 'Email already registered'
          : 'Phone number already registered'
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // Use transaction for atomic operations
    const result = await prisma.$transaction(async (tx) => {
      // Create user
      const user = await tx.user.create({
        data: {
          name,
          email,
          phoneNumber,
          password: hashedPassword,
          role: userRole,
        },
      });

      let manager = null;
      
      // If role is MANAGER, create manager record
      if (userRole === 'MANAGER') {
        manager = await tx.manager.create({
          data: {
            userId: user.id,
            department: department,
          },
        });
      }

      return { user, manager };
    });

    // Remove password from response
    const { password: _, ...userWithoutPassword } = result.user;

    // Prepare response
    const response = {
      user: userWithoutPassword
    };

    // Include manager data if available
    if (result.manager) {
      response.manager = result.manager;
    }

    res.status(201).json(response);
  } catch (error) {
    console.error('Registration error:', error);
    res.status(400).json({ 
      error: 'Registration failed',
      details: error.message
    });
  }
};

const login = async (req, res) => {
  const { phoneNumber, password } = req.body;

  try {
    // Check if user exists
    const user = await prisma.user.findFirst({
      where: { phoneNumber },
      include: { Manager: true }
    });
    
    if (!user) {
      return res.status(401).json({ error: 'Invalid phone number or password' });
    }
    
    // Check if password is correct
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({ error: 'Invalid phone number or password' });
    }

    // Generate JWT token with role
    const token = jwt.sign(
      { 
        userId: user.id,
        role: user.role 
      }, 
      process.env.JWT_SECRET,
      { expiresIn: '5h' }
    );

    // Store token in database
    await prisma.token.create({
      data: {
        token,
        userId: user.id,
        expiresAt: new Date(Date.now() + 3600 * 5000), // 5 hours
      },
    });
    
    // Return user and token with role
    res.json({ 
      user: {
        id: user.id,
        name: user.name,
        phoneNumber: user.phoneNumber,
        role: user.role,
        email: user.email,
        photoUrl: user.photoUrl,
        department: user.Manager?.department // Include department if manager
      }, 
      token 
    });
  } catch (error) {
    console.error(`Login error: ${error.message}`);
    res.status(500).json({ error: 'Server error during login', details: error.message });
  }
};

const logout = async (req, res) => {
  try {
    await prisma.token.deleteMany({
      where: { token: req.token },
    });
    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Logout failed' });
  }
};

module.exports = { register, login, logout };