const calculateLoginHours = async (req, res) => {
  try {
    // Prevent caching
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');

    const { userId } = req.params;
    const { startDate, endDate } = req.query;

    console.log('\n=== Login Hours Calculation ===');
    console.log('Request details:', {
      userId,
      startDate,
      endDate,
      headers: req.headers
    });

    // Validate user exists
    const user = await prisma.salesRep.findUnique({
      where: { id: parseInt(userId) }
    });

    if (!user) {
      console.log('❌ User not found:', userId);
      return res.status(404).json({ error: 'User not found' });
    }

    console.log('✅ User found:', user.id);

    // Build date filter if provided
    let dateFilter = {};
    if (startDate && endDate) {
      dateFilter = {
        createdAt: {
          gte: new Date(startDate),
          lte: new Date(endDate)
        }
      };
    }

    console.log('🔍 Date filter:', dateFilter);

    // Get all tokens for the user
    const tokens = await prisma.token.findMany({
      where: {
        salesRepId: parseInt(userId),
        ...dateFilter
      },
      select: {
        createdAt: true,
        expiresAt: true
      },
      orderBy: {
        createdAt: 'asc'
      }
    });

    console.log('📊 Found tokens:', tokens.length);
    console.log('Token details:', tokens.map(t => ({
      createdAt: t.createdAt,
      expiresAt: t.expiresAt,
      duration: t.expiresAt ? (t.expiresAt.getTime() - t.createdAt.getTime()) / (1000 * 60) : 0
    })));

    // Calculate total login hours
    let totalMinutes = 0;
    let sessionCount = 0;

    tokens.forEach(token => {
      if (token.expiresAt) {
        const duration = token.expiresAt.getTime() - token.createdAt.getTime();
        totalMinutes += duration / (1000 * 60); // Convert milliseconds to minutes
        sessionCount++;
      }
    });

    const hours = Math.floor(totalMinutes / 60);
    const minutes = Math.round(totalMinutes % 60);

    const response = {
      userId,
      totalHours: hours,
      totalMinutes: minutes,
      sessionCount,
      formattedDuration: `${hours}h ${minutes}m`,
      averageSessionDuration: sessionCount > 0 ? `${Math.floor(totalMinutes / sessionCount)}m` : '0m'
    };

    console.log('📈 Login hours response:', response);
    res.json(response);
  } catch (error) {
    console.error('❌ Error calculating login hours:', error);
    res.status(500).json({ error: 'Failed to calculate login hours' });
  }
};

// Calculate journey plan visit counts
const calculateJourneyPlanVisits = async (req, res) => {
  try {
    // Prevent caching
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');

    const { userId } = req.params;
    const { startDate, endDate } = req.query;

    console.log('\n=== Journey Visits Calculation ===');
    console.log('Request details:', {
      userId,
      startDate,
      endDate,
      headers: req.headers
    });

    // Validate user exists
    const user = await prisma.salesRep.findUnique({
      where: { id: parseInt(userId) }
    });

    if (!user) {
      console.log('❌ User not found:', userId);
      return res.status(404).json({ error: 'User not found' });
    }

    console.log('✅ User found:', user.id);

    // Build date filter if provided
    let dateFilter = {};
    if (startDate && endDate) {
      dateFilter = {
        date: {
          gte: new Date(startDate),
          lte: new Date(endDate)
        }
      };
    }

    console.log('🔍 Date filter:', dateFilter);

    // Get all journey plans for the user
    const journeyPlans = await prisma.journeyPlan.findMany({
      where: {
        userId: parseInt(userId),
        ...dateFilter
      },
      select: {
        checkInTime: true,
        checkoutTime: true,
        client: {
          select: {
            id: true,
            name: true
          }
        }
      },
      orderBy: {
        date: 'desc'
      }
    });

    console.log('📊 Found journey plans:', journeyPlans.length);
    console.log('Journey plan details:', journeyPlans.map(p => ({
      checkInTime: p.checkInTime,
      checkoutTime: p.checkoutTime,
      client: p.client
    })));

    // Calculate visit statistics
    const completedVisits = journeyPlans.filter(plan => plan.checkInTime && plan.checkoutTime).length;
    const pendingVisits = journeyPlans.filter(plan => plan.checkInTime && !plan.checkoutTime).length;
    const missedVisits = journeyPlans.filter(plan => !plan.checkInTime).length;

    // Group visits by client
    const clientVisits = {};
    journeyPlans.forEach(plan => {
      if (plan.checkInTime && plan.checkoutTime) {
        const clientId = plan.client.id;
        if (!clientVisits[clientId]) {
          clientVisits[clientId] = {
            clientName: plan.client.name,
            visitCount: 0
          };
        }
        clientVisits[clientId].visitCount++;
      }
    });

    const response = {
      userId,
      totalPlans: journeyPlans.length,
      completedVisits,
      pendingVisits,
      missedVisits,
      clientVisits: Object.values(clientVisits),
      completionRate: journeyPlans.length > 0 
        ? `${Math.round((completedVisits / journeyPlans.length) * 100)}%` 
        : '0%'
    };

    console.log('📈 Journey visits response:', response);
    res.json(response);
  } catch (error) {
    console.error('❌ Error calculating journey plan visits:', error);
    res.status(500).json({ error: 'Failed to calculate journey plan visits' });
  }
}; 