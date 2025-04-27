/*
  Warnings:

  - You are about to drop the `Order` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE `Order` DROP FOREIGN KEY `Order_clientId_fkey`;

-- DropForeignKey
ALTER TABLE `Order` DROP FOREIGN KEY `Order_userId_fkey`;

-- DropForeignKey
ALTER TABLE `OrderItem` DROP FOREIGN KEY `OrderItem_orderId_fkey`;

-- DropForeignKey
ALTER TABLE `Report` DROP FOREIGN KEY `Report_orderId_fkey`;

-- DropTable
DROP TABLE `Order`;

-- CreateTable
CREATE TABLE `MyOrder` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `totalAmount` DOUBLE NOT NULL,
    `comment` VARCHAR(191) NOT NULL,
    `customerType` VARCHAR(191) NOT NULL,
    `customerId` VARCHAR(191) NOT NULL,
    `customerName` VARCHAR(191) NOT NULL,
    `orderDate` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `riderId` INTEGER NULL,
    `riderName` VARCHAR(191) NULL,
    `status` INTEGER NOT NULL DEFAULT 0,
    `approvedTime` VARCHAR(191) NULL,
    `dispatchTime` VARCHAR(191) NULL,
    `deliveryLocation` VARCHAR(191) NULL,
    `complete_latitude` VARCHAR(191) NULL,
    `complete_longitude` VARCHAR(191) NULL,
    `complete_address` VARCHAR(191) NULL,
    `pickupTime` VARCHAR(191) NULL,
    `deliveryTime` VARCHAR(191) NULL,
    `cancel_reason` VARCHAR(191) NULL,
    `recepient` VARCHAR(191) NULL,
    `userId` INTEGER NOT NULL,
    `clientId` INTEGER NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `MyOrder_userId_idx`(`userId`),
    INDEX `MyOrder_clientId_idx`(`clientId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `_MyOrderToOrderItem` (
    `A` INTEGER NOT NULL,
    `B` INTEGER NOT NULL,

    UNIQUE INDEX `_MyOrderToOrderItem_AB_unique`(`A`, `B`),
    INDEX `_MyOrderToOrderItem_B_index`(`B`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `_MyOrderToReport` (
    `A` INTEGER NOT NULL,
    `B` INTEGER NOT NULL,

    UNIQUE INDEX `_MyOrderToReport_AB_unique`(`A`, `B`),
    INDEX `_MyOrderToReport_B_index`(`B`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `MyOrder` ADD CONSTRAINT `MyOrder_clientId_fkey` FOREIGN KEY (`clientId`) REFERENCES `Clients`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `MyOrder` ADD CONSTRAINT `MyOrder_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `SalesRep`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_MyOrderToOrderItem` ADD CONSTRAINT `_MyOrderToOrderItem_A_fkey` FOREIGN KEY (`A`) REFERENCES `MyOrder`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_MyOrderToOrderItem` ADD CONSTRAINT `_MyOrderToOrderItem_B_fkey` FOREIGN KEY (`B`) REFERENCES `OrderItem`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_MyOrderToReport` ADD CONSTRAINT `_MyOrderToReport_A_fkey` FOREIGN KEY (`A`) REFERENCES `MyOrder`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_MyOrderToReport` ADD CONSTRAINT `_MyOrderToReport_B_fkey` FOREIGN KEY (`B`) REFERENCES `Report`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
