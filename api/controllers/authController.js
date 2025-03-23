const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const register = async (req, res) => {
  const { name, email, password, phoneNumber } = req.body;

  try {
    // Validate required fields
    if (!name || !email || !password || !phoneNumber) {
      return res.status(400).json({ 
        error: 'Registration failed',
        details: 'All fields are required: name, email, password, and phoneNumber'
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
    const user = await prisma.user.create({
      data: {
        name,
        email,
        phoneNumber,
        password: hashedPassword,
      },
    });

    // Remove password from response
    const { password: _, ...userWithoutPassword } = user;
    res.status(201).json({ user: userWithoutPassword });
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
    console.log(`Login attempt for phoneNumber: ${phoneNumber}`);
    
    // Check if user exists
    const user = await prisma.user.findFirst({
      where: { phoneNumber }
    });
    
    if (!user) {
      console.log(`User not found: ${phoneNumber}`);
      return res.status(401).json({ error: 'Invalid phone number or password' });
    }
    
    // Check if password is correct
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      console.log(`Invalid password for user: ${phoneNumber}`);
      return res.status(401).json({ error: 'Invalid phone number or password' });
    }

    // Generate JWT token
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: '5h',
    });

    // Store token in database
    await prisma.token.create({
      data: {
        token,
        userId: user.id,
        expiresAt: new Date(Date.now() + 3600 * 5000), // 1 hour
      },
    });

    console.log(`Login successful for user: ${phoneNumber}`);
    
    // Return user and token
    res.json({ 
      user: {
        id: user.id,
        name: user.name,
        phoneNumber: user.phoneNumber
        // Don't include password in the response
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