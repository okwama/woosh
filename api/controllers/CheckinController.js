const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

exports.checkIn = async (req, res) => {
  const { outletId, latitude, longitude, notes } = req.body;
  const managerId = req.user.id; // Extracted from token in middleware

  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const existingCheckin = await prisma.managerCheckin.findFirst({
      where: { managerId, date: today },
    });

    if (existingCheckin) {
      return res.status(400).json({ message: 'Already checked in today' });
    }

    const outlet = await prisma.outlet.findUnique({
      where: { id: outletId },
    });

    if (!outlet) {
      return res.status(400).json({ message: 'Invalid outlet ID' });
    }

    const checkin = await prisma.managerCheckin.create({
      data: {
        managerId,
        outletId,
        date: today,
        checkInAt: new Date(),
        latitude,
        longitude,
        notes,
      },
    });

    res.status(201).json({ message: 'Checked in successfully', checkin });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Server error' });
  }
};

exports.checkOut = async (req, res) => {
  const managerId = req.user.id;

  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const checkin = await prisma.managerCheckin.findFirst({
      where: { managerId, date: today },
    });

    if (!checkin || checkin.checkOutAt) {
      return res.status(400).json({ message: 'No active check-in found' });
    }

    const updated = await prisma.managerCheckin.update({
      where: { id: checkin.id },
      data: { checkOutAt: new Date() },
    });

    res.json({ message: 'Checked out successfully', checkin: updated });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Server error' });
  }
};
