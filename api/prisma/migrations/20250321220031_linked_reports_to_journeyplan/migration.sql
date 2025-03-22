-- AlterTable
ALTER TABLE `Report` ADD COLUMN `journeyPlanId` INTEGER NULL;

-- CreateIndex
CREATE INDEX `Report_journeyPlanId_fkey` ON `Report`(`journeyPlanId`);

-- AddForeignKey
ALTER TABLE `Report` ADD CONSTRAINT `Report_journeyPlanId_fkey` FOREIGN KEY (`journeyPlanId`) REFERENCES `JourneyPlan`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
