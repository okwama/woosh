const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Create a generic report
const createReport = async (req, res) => {
    try {
        const { type, journeyPlanId, userId, orderId, outletId, details } = req.body;

        // Create a new report
        const report = await prisma.report.create({
            data: {
                type,
                journeyPlanId,
                userId,
                orderId,
                outletId,
            },
        });

        let specificReport;
        if (type === 'FEEDBACK') {
            specificReport = await prisma.feedbackReport.create({
                data: {
                    reportId: report.id,
                    comment: details.comment,
                },
            });
        } else if (type === 'PRODUCT_AVAILABILITY') {
            specificReport = await prisma.productReport.create({
                data: {
                    reportId: report.id,
                    productName: details.productName,
                    quantity: details.quantity,
                    comment: details.comment,
                },
            });
        } else if (type === 'VISIBILITY_ACTIVITY') {
            specificReport = await prisma.visibilityReport.create({
                data: {
                    reportId: report.id,
                    comment: details.comment,
                    imageUrl: details.imageUrl,
                },
            });
        }

        res.status(201).json({ report, specificReport });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error creating report' });
    }
};

// Get all reports
const getAllReports = async (req, res) => {
    try {
        const reports = await prisma.report.findMany({
            include: {
                feedbackReport: true,
                productReport: true,
                visibilityReport: true,
            },
        });
        res.json(reports);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error retrieving reports' });
    }
};

// Get a single report by ID
const getReportById = async (req, res) => {
    try {
        const { id } = req.params;
        const report = await prisma.report.findUnique({
            where: { id: parseInt(id) },
            include: {
                feedbackReport: true,
                productReport: true,
                visibilityReport: true,
            },
        });

        if (!report) {
            return res.status(404).json({ error: 'Report not found' });
        }

        res.json(report);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error retrieving report' });
    }
};

// Update a report
const updateReport = async (req, res) => {
    try {
        const { id } = req.params;
        const { type, details } = req.body;

        const report = await prisma.report.update({
            where: { id: parseInt(id) },
            data: { type },
        });

        let specificReport;
        if (type === 'FEEDBACK') {
            specificReport = await prisma.feedbackReport.update({
                where: { reportId: report.id },
                data: { comment: details.comment },
            });
        } else if (type === 'PRODUCT_AVAILABILITY') {
            specificReport = await prisma.productReport.update({
                where: { reportId: report.id },
                data: {
                    productName: details.productName,
                    quantity: details.quantity,
                    comment: details.comment,
                },
            });
        } else if (type === 'VISIBILITY_ACTIVITY') {
            specificReport = await prisma.visibilityReport.update({
                where: { reportId: report.id },
                data: {
                    comment: details.comment,
                    imageUrl: details.imageUrl,
                },
            });
        }

        res.json({ report, specificReport });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error updating report' });
    }
};

// Delete a report
const deleteReport = async (req, res) => {
    try {
        const { id } = req.params;

        await prisma.report.delete({ where: { id: parseInt(id) } });

        res.json({ message: 'Report deleted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error deleting report' });
    }
};

module.exports = {
    createReport,
    getAllReports,
    getReportById,
    updateReport,
    deleteReport,
};
