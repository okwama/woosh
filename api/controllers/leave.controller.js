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

      console.log('Request headers:', req.headers);
      console.log('Authentication:', req.headers.authorization ? 'Present' : 'Missing');
      console.log('Content-Type:', req.headers['content-type']);
      console.log('Request body:', req.body);
      console.log('Form fields:', {
        leaveType: req.body.leaveType,
        startDate: req.body.startDate,
        endDate: req.body.endDate,
        reason: req.body.reason,
        file: req.file ? req.file.filename : 'No file uploaded'
      });
      
      // Debug authentication
      console.log('User object:', req.user);
      
      // Manual check for fields to provide better error messages
      const missingFields = [];
      if (!req.body.leaveType) missingFields.push('leaveType');
      if (!req.body.startDate) missingFields.push('startDate');
      if (!req.body.endDate) missingFields.push('endDate');
      if (!req.body.reason) missingFields.push('reason');
      
      if (missingFields.length > 0) {
        return res.status(400).json({ 
          error: `Missing required fields: ${missingFields.join(', ')}`,
          received: req.body
        });
      }
      
      const { leaveType, startDate, endDate, reason } = req.body;
      
      // Check if user is authenticated
      if (!req.user) {
        return res.status(401).json({ 
          error: 'User not authenticated. Please log in again.',
          authHeader: req.headers.authorization ? 'Present' : 'Missing'
        });
      }
      
      // Use a hardcoded user ID for testing if needed
      // const userId = 1; // Uncomment for testing
      const userId = req.user.id;
      console.log('Authenticated user:', { userId, user: req.user });

      // Simple date validation and parsing
      if (!startDate || !endDate) {
        return res.status(400).json({ error: 'Start date and end date are required' });
      }

      // Parse dates safely
      let start, end;
      
      try {
        // Format to ensure YYYY-MM-DD
        const formatDateString = (dateStr) => {
          // Check if the date is in format YYYY-MM-DD
          if (typeof dateStr === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
            return dateStr;
          }
          
          // Try to parse as date and reformat
          try {
            const date = new Date(dateStr);
            if (!isNaN(date.getTime())) {
              return date.toISOString().split('T')[0];
            }
          } catch (e) {
            console.error('Date parsing error:', e);
          }
          
          return null;
        };
        
        const formattedStartDate = formatDateString(startDate);
        const formattedEndDate = formatDateString(endDate);
        
        if (!formattedStartDate || !formattedEndDate) {
          return res.status(400).json({ 
            error: 'Invalid date format. Please use YYYY-MM-DD format.' 
          });
        }
        
        start = new Date(formattedStartDate);
        end = new Date(formattedEndDate);
        
        console.log('Parsed dates:', { 
          startDate, endDate,
          formattedStartDate, formattedEndDate,
          start: start.toISOString(), 
          end: end.toISOString() 
        });
        
      } catch (error) {
        console.error('Date parsing error:', error);
        return res.status(400).json({
          error: 'Invalid date format. Please use YYYY-MM-DD format.'
        });
      }

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