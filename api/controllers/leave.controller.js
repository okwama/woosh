const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configure multer for file upload
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = 'uploads/leave-documents';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    cb(null, Date.now() + '-' + file.originalname);
  }
});

const upload = multer({
  storage: storage,
  fileFilter: function (req, file, cb) {
    const allowedTypes = ['.jpg', '.jpeg', '.png', '.pdf'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedTypes.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only JPG, PNG & PDF files are allowed.'));
    }
  },
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  }
}).single('attachment');

// Submit leave application
exports.submitLeave = async (req, res) => {
  try {
    upload(req, res, async function (err) {
      if (err) {
        return res.status(400).json({ error: err.message });
      }

      const { leaveType, startDate, endDate, reason } = req.body;
      const userId = req.user.id;

      // Validate dates
      const start = new Date(startDate);
      const end = new Date(endDate);

      if (end < start) {
        return res.status(400).json({
          error: 'End date cannot be before start date'
        });
      }

      const leave = await prisma.leave.create({
        data: {
          userId,
          leaveType,
          startDate: start,
          endDate: end,
          reason,
          attachment: req.file ? req.file.path : null
        }
      });

      res.status(201).json(leave);
    });
  } catch (error) {
    console.error('Error submitting leave:', error);
    res.status(500).json({ error: 'Failed to submit leave application' });
  }
};

// Get user's leave applications
exports.getUserLeaves = async (req, res) => {
  try {
    const userId = req.user.id;
    const leaves = await prisma.leave.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' }
    });

    res.json(leaves);
  } catch (error) {
    console.error('Error fetching leaves:', error);
    res.status(500).json({ error: 'Failed to fetch leave applications' });
  }
};

// Get all leave applications (for admin)
exports.getAllLeaves = async (req, res) => {
  try {
    const leaves = await prisma.leave.findMany({
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true
          }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json(leaves);
  } catch (error) {
    console.error('Error fetching all leaves:', error);
    res.status(500).json({ error: 'Failed to fetch leave applications' });
  }
};

// Update leave status (for admin)
exports.updateLeaveStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!['PENDING', 'APPROVED', 'REJECTED'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    const leave = await prisma.leave.update({
      where: { id: parseInt(id) },
      data: { status }
    });

    res.json(leave);
  } catch (error) {
    console.error('Error updating leave status:', error);
    res.status(500).json({ error: 'Failed to update leave status' });
  }
}; 