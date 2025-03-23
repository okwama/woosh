/*
  Warnings:

  - You are about to drop the column `product` on the `Order` table. All the data in the column will be lost.
  - You are about to drop the column `inventoryStatus` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `outletAddress` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `outletName` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `product` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `reorderLevel` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `salesDate` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `stockLevel` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `totalSalesValue` on the `Report` table. All the data in the column will be lost.
  - Added the required column `type` to the `Report` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE `Report` DROP FOREIGN KEY `Report_orderId_fkey`;

-- AlterTable
ALTER TABLE `Order` DROP COLUMN `product`,
    ADD COLUMN `productId` INTEGER NULL;

-- AlterTable
ALTER TABLE `Report` DROP COLUMN `inventoryStatus`,
    DROP COLUMN `outletAddress`,
    DROP COLUMN `outletName`,
    DROP COLUMN `product`,
    DROP COLUMN `reorderLevel`,
    DROP COLUMN `salesDate`,
    DROP COLUMN `stockLevel`,
    DROP COLUMN `totalSalesValue`,
    ADD COLUMN `comment` VARCHAR(191) NULL,
    ADD COLUMN `imageUrl` VARCHAR(191) NULL,
    ADD COLUMN `productName` VARCHAR(191) NULL,
    ADD COLUMN `type` VARCHAR(191) NOT NULL,
    MODIFY `orderId` INTEGER NULL,
    MODIFY `quantity` INTEGER NULL;

-- CreateTable
CREATE TABLE `Product` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(191) NOT NULL,
    `description` VARCHAR(191) NULL,
    `price` DOUBLE NOT NULL,
    `currentStock` INTEGER NOT NULL,
    `reorderPoint` INTEGER NOT NULL,
    `orderQuantity` INTEGER NOT NULL DEFAULT 0,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,
    `outletId` INTEGER NOT NULL,

    INDEX `Product_outletId_fkey`(`outletId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE INDEX `Order_productId_fkey` ON `Order`(`productId`);

-- AddForeignKey
ALTER TABLE `Order` ADD CONSTRAINT `Order_productId_fkey` FOREIGN KEY (`productId`) REFERENCES `Product`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Report` ADD CONSTRAINT `Report_orderId_fkey` FOREIGN KEY (`orderId`) REFERENCES `Order`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Product` ADD CONSTRAINT `Product_outletId_fkey` FOREIGN KEY (`outletId`) REFERENCES `Outlet`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
