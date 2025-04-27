const { getPrismaClient } = require('../lib/prisma');
const prisma = getPrismaClient();

exports.checkIn = async (req, res) => {
  const { clientId, latitude, longitude, notes, imageUrl } = req.body;
  const managerId = req.user.id; // Extracted from token in middleware

  try {
    console.log('Attempting check-in with managerId:', managerId);
    
    // First verify the manager exists
    const manager = await prisma.manager.findUnique({
      where: { userId: managerId }, // Changed from id to userId
    });

    if (!manager) {
      console.log('Manager not found for userId:', managerId);
      return res.status(400).json({ message: 'Invalid manager ID' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const existingCheckin = await prisma.managerCheckin.findFirst({
      where: { managerId: manager.id, date: today }, // Use manager.id here
    });

    if (existingCheckin) {
      return res.status(400).json({ message: 'Already checked in today' });
    }

    const client = await prisma.clients.findUnique({
      where: { id: parseInt(clientId) },
    });

    if (!client) {
      return res.status(400).json({ message: 'Invalid client ID' });
    }

    const checkin = await prisma.managerCheckin.create({
      data: {
        managerId: manager.id, // Use manager.id here
        clientId: parseInt(clientId),
        date: today,
        checkInAt: new Date(),
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        notes,
        imageUrl,
      },
    });

    res.status(201).json({ message: 'Checked in successfully', checkin });
  } catch (error) {
    console.error('Check-in error:', error);
    res.status(500).json({ error: 'Server error' });
  }
};

exports.checkOut = async (req, res) => {
  const managerId = req.user.id;
  const { latitude, longitude } = req.body; // These can be undefined

  try {
    console.log('Attempting check-out for userId:', managerId);
    
    // First verify the manager exists
    const manager = await prisma.manager.findUnique({
      where: { userId: managerId },
    });

    if (!manager) {
      console.log('Manager not found for userId:', managerId);
      return res.status(400).json({ message: 'Invalid manager ID' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const checkin = await prisma.managerCheckin.findFirst({
      where: { 
        managerId: manager.id,
        date: today 
      },
    });

    if (!checkin) {
      return res.status(400).json({ message: 'No active check-in found' });
    }

    if (checkin.checkOutAt) {
      return res.status(400).json({ message: 'Already checked out' });
    }

    // Only include location data if both values are provided
    const updateData = {
      checkOutAt: new Date(),
    };

    // Only add location if both values are provided and valid
    if (latitude !== undefined && longitude !== undefined) {
      updateData.checkoutLatitude = parseFloat(latitude);
      updateData.checkoutLongitude = parseFloat(longitude);
    }

    const updated = await prisma.managerCheckin.update({
      where: { id: checkin.id },
      data: updateData,
    });

    res.json({ 
      message: 'Checked out successfully', 
      checkin: updated 
    });
  } catch (error) {
    console.error('Check-out error:', error);
    res.status(500).json({ error: 'Server error' });
  }
};

// Add a new endpoint to get client location
exports.getClientLocation = async (req, res) => {
  try {
    const { clientId } = req.params;
    
    const client = await prisma.clients.findUnique({
      where: { id: parseInt(clientId) },
      select: {
        id: true,
        name: true,
        latitude: true,
        longitude: true,
        location: true,
      }
    });
    
    if (!client) {
      return res.status(404).json({ error: 'Client not found' });
    }
    
    res.status(200).json(client);
  } catch (error) {
    console.error('Error getting client location:', error);
    res.status(500).json({ error: 'Failed to get client location' });
  }
};

exports.getHistory = async (req, res) => {
  const userId = req.user.id;
  const { page = 1, limit = 10, filter, startDate, endDate } = req.query;
  const skip = (page - 1) * limit;

  try {
    // First get the manager record
    const manager = await prisma.manager.findUnique({
      where: { userId },
    });

    if (!manager) {
      return res.status(400).json({ message: 'Invalid manager ID' });
    }

    let dateFilter = {};
    const now = new Date();
    
    if (startDate && endDate) {
      // Custom date range
      dateFilter = {
        date: {
          gte: new Date(startDate),
          lte: new Date(endDate)
        }
      };
    } else if (filter) {
      const startDate = new Date();
      
      switch (filter) {
        case 'week':
          startDate.setDate(now.getDate() - 7);
          break;
        case 'month':
          startDate.setMonth(now.getMonth() - 1);
          break;
        case 'today':
          startDate.setHours(0, 0, 0, 0);
          break;
      }
      
      dateFilter = {
        date: {
          gte: startDate,
          lte: now
        }
      };
    }

    const [history, total] = await Promise.all([
      prisma.managerCheckin.findMany({
        where: {
          managerId: manager.id,
          ...dateFilter
        },
        include: {
          client: {
            select: {
              id: true,
              name: true,
              address: true,
            },
          },
        },
        orderBy: {
          date: 'desc',
        },
        take: parseInt(limit),
        skip: parseInt(skip),
      }),
      prisma.managerCheckin.count({
        where: {
          managerId: manager.id,
          ...dateFilter
        },
      }),
    ]);

    res.json({
      history,
      meta: {
        total,
        page: parseInt(page),
        totalPages: Math.ceil(total / limit),
        hasMore: skip + history.length < total
      }
    });
  } catch (error) {
    console.error('Error fetching check-in history:', error);
    res.status(500).json({ error: 'Failed to fetch check-in history' });
  }
};

exports.getTotalWorkingHours = async (req, res) => {
  const userId = req.user.id;
  const { period } = req.query; // 'today', 'week', 'month', or 'all'

  try {
    // First get the manager record
    const manager = await prisma.manager.findUnique({
      where: { userId },
    });

    if (!manager) {
      return res.status(400).json({ message: 'Invalid manager ID' });
    }

    let dateFilter = {};
    const now = new Date();
    
    if (period) {
      const startDate = new Date();
      
      switch (period) {
        case 'week':
          startDate.setDate(now.getDate() - 7);
          break;
        case 'month':
          startDate.setMonth(now.getMonth() - 1);
          break;
        case 'today':
          startDate.setHours(0, 0, 0, 0);
          break;
      }
      
      dateFilter = {
        date: {
          gte: startDate,
          lte: now
        }
      };
    }

    const checkins = await prisma.managerCheckin.findMany({
      where: {
        managerId: manager.id,
        checkOutAt: { not: null }, // Only count completed check-ins
        ...dateFilter
      },
      select: {
        checkInAt: true,
        checkOutAt: true,
      },
    });

    let totalMinutes = 0;
    let completedVisits = 0;

    checkins.forEach(checkin => {
      if (checkin.checkInAt && checkin.checkOutAt) {
        const duration = checkin.checkOutAt.getTime() - checkin.checkInAt.getTime();
        totalMinutes += duration / (1000 * 60); // Convert milliseconds to minutes
        completedVisits++;
      }
    });

    const hours = Math.floor(totalMinutes / 60);
    const minutes = Math.round(totalMinutes % 60);

    res.json({
      totalHours: hours,
      totalMinutes: minutes,
      completedVisits,
      formattedDuration: `${hours}h ${minutes}m`,
    });
  } catch (error) {
    console.error('Error calculating working hours:', error);
    res.status(500).json({ error: 'Failed to calculate working hours' });
  }
};
