const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const register = async (req, res) => {
  const { name, email, password } = req.body;

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: hashedPassword,
      },
    });
    res.status(201).json({ user });
  } catch (error) {
    res.status(400).json({ error: 'Registration failed' });
  }
};

const login = async (req, res) => {
  const { email, password } = req.body;

  try {
    console.log(`Login attempt for email: ${email}`);
    
    // Check if email exists
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      console.log(`User not found: ${email}`);
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    
    // Check if password is correct
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      console.log(`Invalid password for user: ${email}`);
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    // Generate JWT token
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, {
      expiresIn: '1h',
    });

    // Store token in database
    await prisma.token.create({
      data: {
        token,
        userId: user.id,
        expiresAt: new Date(Date.now() + 3600 * 1000), // 1 hour
      },
    });

    console.log(`Login successful for user: ${email}`);
    
    // Return user and token
    res.json({ 
      user: {
        id: user.id,
        name: user.name,
        email: user.email
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