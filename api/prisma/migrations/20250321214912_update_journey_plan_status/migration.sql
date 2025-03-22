/*
  Warnings:

  - You are about to alter the column `status` on the `JourneyPlan` table. The data in that column could be lost. The data in that column will be cast from `VarChar(191)` to `Int`.

*/
-- DropForeignKey
ALTER TABLE `JourneyPlan` DROP FOREIGN KEY `JourneyPlan_userId_fkey`;

-- AlterTable
ALTER TABLE `JourneyPlan` MODIFY `userId` INTEGER NULL,
    MODIFY `status` INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE `Report` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `orderId` INTEGER NOT NULL,
    `product` VARCHAR(191) NOT NULL,
    `quantity` INTEGER NOT NULL,
    `outletId` INTEGER NOT NULL,
    `outletName` VARCHAR(191) NOT NULL,
    `outletAddress` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `totalSalesValue` DOUBLE NOT NULL,
    `stockLevel` INTEGER NOT NULL,
    `reorderLevel` INTEGER NOT NULL,
    `salesDate` DATETIME(3) NOT NULL,
    `userId` INTEGER NOT NULL,
    `inventoryStatus` VARCHAR(191) NOT NULL,

    INDEX `Report_orderId_fkey`(`orderId`),
    INDEX `Report_userId_fkey`(`userId`),
    INDEX `Report_outletId_fkey`(`outletId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `JourneyPlan` ADD CONSTRAINT `JourneyPlan_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Report` ADD CONSTRAINT `Report_orderId_fkey` FOREIGN KEY (`orderId`) REFERENCES `Order`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Report` ADD CONSTRAINT `Report_outletId_fkey` FOREIGN KEY (`outletId`) REFERENCES `Outlet`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Report` ADD CONSTRAINT `Report_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
