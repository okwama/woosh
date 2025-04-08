const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const ImageKit = require('imagekit');
const multer = require('multer');

// Configure ImageKit
const imagekit = new ImageKit({
  publicKey: process.env.IMAGEKIT_PUBLIC_KEY,
  privateKey: process.env.IMAGEKIT_PRIVATE_KEY,
  urlEndpoint: process.env.IMAGEKIT_URL_ENDPOINT
});

const updateProfilePhoto = async (req, res) => {
  try {
    const userId = req.user.id;
    
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    // Upload file to ImageKit
    const result = await imagekit.upload({
      file: req.file.buffer,
      fileName: `profile-${userId}-${Date.now()}`,
      folder: '/whoosh/profile_photos',
    });

    // Update user's photoUrl in database
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: { photoUrl: result.url },
      select: {
        id: true,
        name: true,
        email: true,
        phoneNumber: true,
        photoUrl: true,
        role: true,
      },
    });

    res.json({
      message: 'Profile photo updated successfully',
      user: updatedUser,
    });
  } catch (error) {
    console.error('Profile photo update error:', error);
    res.status(500).json({ message: 'Failed to update profile photo' });
  }
};

const getProfile = async (req, res) => {
  try {
    const userId = req.user.id;

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        email: true,
        phoneNumber: true,
        photoUrl: true,
        role: true,
      },
    });

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({ user });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ message: 'Failed to fetch profile' });
  }
};

module.exports = {
  updateProfilePhoto,
  getProfile,
};