const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Configure storage
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = 'uploads/images';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    // Generate unique filename with original extension
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

// Configure upload middleware
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  },
  fileFilter: function (req, file, cb) {
    // Validate file type
    const allowedTypes = ['.jpg', '.jpeg', '.png', '.pdf'	];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedTypes.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only JPG and PNG files are allowed.'));
    }
  }
}).single('file');

// Upload image endpoint
exports.uploadImage = async (req, res) => {
  try {
    upload(req, res, async function (err) {
      if (err instanceof multer.MulterError) {
        // A Multer error occurred during upload
        console.error('Multer error:', err);
        return res.status(400).json({ error: err.message });
      } else if (err) {
        // An unknown error occurred
        console.error('Upload error:', err);
        return res.status(400).json({ error: err.message });
      }
      
      if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
      }

      // Get the base URL from environment variable or use a default
      const baseUrl = process.env.BASE_URL || 'https://https-github-com-okwama-woosh-api.vercel.app';
      
      // Return the complete URL to the uploaded file
      const imageUrl = `${baseUrl}/uploads/images/${req.file.filename}`;
      
      console.log('File uploaded successfully:', {
        originalName: req.file.originalname,
        filename: req.file.filename,
        size: req.file.size,
        url: imageUrl
      });

      res.json({ imageUrl });
    });
  } catch (error) {
    console.error('Error in uploadImage:', error);
    res.status(500).json({ error: 'Failed to upload image' });
  }
}; 