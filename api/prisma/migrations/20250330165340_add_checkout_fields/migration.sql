-- AlterTable
ALTER TABLE `JourneyPlan` ADD COLUMN `checkoutLatitude` DOUBLE NULL,
    ADD COLUMN `checkoutLongitude` DOUBLE NULL,
    ADD COLUMN `checkoutTime` DATETIME(3) NULL;
