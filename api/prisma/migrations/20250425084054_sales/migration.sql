/*
  Warnings:

  - You are about to drop the column `imageUrl` on the `Product` table. All the data in the column will be lost.
  - You are about to drop the column `price` on the `Product` table. All the data in the column will be lost.
  - You are about to drop the `users` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE `JourneyPlan` DROP FOREIGN KEY `JourneyPlan_userId_fkey`;

-- DropForeignKey
ALTER TABLE `Order` DROP FOREIGN KEY `Order_userId_fkey`;

-- DropForeignKey
ALTER TABLE `OrderItem` DROP FOREIGN KEY `OrderItem_orderId_fkey`;

-- DropForeignKey
ALTER TABLE `OrderItem` DROP FOREIGN KEY `OrderItem_productId_fkey`;

-- DropForeignKey
ALTER TABLE `Product` DROP FOREIGN KEY `Product_outletId_fkey`;

-- DropForeignKey
ALTER TABLE `Report` DROP FOREIGN KEY `Report_userId_fkey`;

-- DropForeignKey
ALTER TABLE `Token` DROP FOREIGN KEY `Token_salesRepId_fkey`;

-- DropForeignKey
ALTER TABLE `leaves` DROP FOREIGN KEY `leaves_userId_fkey`;

-- DropForeignKey
ALTER TABLE `managers` DROP FOREIGN KEY `managers_userId_fkey`;

-- DropForeignKey
ALTER TABLE `users` DROP FOREIGN KEY `users_regionsId_fkey`;

-- AlterTable
ALTER TABLE `Product` DROP COLUMN `imageUrl`,
    DROP COLUMN `price`,
    ADD COLUMN `image` VARCHAR(191) NULL DEFAULT '',
    MODIFY `currentStock` INTEGER NULL,
    MODIFY `outletId` INTEGER NULL;

-- DropTable
DROP TABLE `users`;

-- CreateTable
CREATE TABLE `SalesRep` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(191) NOT NULL,
    `email` VARCHAR(191) NOT NULL,
    `phoneNumber` VARCHAR(191) NOT NULL,
    `password` VARCHAR(191) NOT NULL,
    `countryId` INTEGER NOT NULL,
    `region_id` INTEGER NOT NULL,
    `region` VARCHAR(191) NOT NULL,
    `role` VARCHAR(191) NULL DEFAULT 'USER',
    `status` INTEGER NULL DEFAULT 0,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,
    `photoUrl` VARCHAR(191) NULL DEFAULT '',

    UNIQUE INDEX `SalesRep_email_key`(`email`),
    UNIQUE INDEX `SalesRep_phoneNumber_key`(`phoneNumber`),
    INDEX `SalesRep_countryId_fkey`(`countryId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `SalesRep` ADD CONSTRAINT `SalesRep_countryId_fkey` FOREIGN KEY (`countryId`) REFERENCES `Country`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `managers` ADD CONSTRAINT `managers_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Token` ADD CONSTRAINT `Token_salesRepId_fkey` FOREIGN KEY (`salesRepId`) REFERENCES `SalesRep`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Order` ADD CONSTRAINT `Order_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `OrderItem` ADD CONSTRAINT `OrderItem_orderId_fkey` FOREIGN KEY (`orderId`) REFERENCES `MyOrder`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `OrderItem` ADD CONSTRAINT `OrderItem_productId_fkey` FOREIGN KEY (`productId`) REFERENCES `Product`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `JourneyPlan` ADD CONSTRAINT `JourneyPlan_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Report` ADD CONSTRAINT `Report_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Product` ADD CONSTRAINT `Product_outletId_fkey` FOREIGN KEY (`outletId`) REFERENCES `Outlet`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `leaves` ADD CONSTRAINT `leaves_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- RedefineIndex
CREATE INDEX `Order_userId_fkey` ON `Order`(`userId`);
DROP INDEX `Order_salesRepId_fkey` ON `Order`;

-- RedefineIndex
CREATE INDEX `OrderItem_orderId_fkey` ON `OrderItem`(`orderId`);
DROP INDEX `OrderItem_orderId_idx` ON `OrderItem`;

-- RedefineIndex
CREATE INDEX `OrderItem_productId_fkey` ON `OrderItem`(`productId`);
DROP INDEX `OrderItem_productId_idx` ON `OrderItem`;

-- RedefineIndex
CREATE INDEX `Report_userId_fkey` ON `Report`(`userId`);
DROP INDEX `Report_salesRepId_fkey` ON `Report`;

-- RedefineIndex
CREATE INDEX `Token_userId_fkey` ON `Token`(`salesRepId`);
DROP INDEX `Token_salesRepId_fkey` ON `Token`;

-- RedefineIndex
CREATE INDEX `leaves_userId_fkey` ON `leaves`(`userId`);
DROP INDEX `leaves_salesRepId_fkey` ON `leaves`;
