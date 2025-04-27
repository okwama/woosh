/*
  Warnings:

  - You are about to drop the `_MyOrderToOrderItem` table. If the table is not empty, all the data it contains will be lost.
  - A unique constraint covering the columns `[orderId,productId,priceOptionId]` on the table `OrderItem` will be added. If there are existing duplicate values, this will fail.

*/
-- DropForeignKey
ALTER TABLE `_MyOrderToOrderItem` DROP FOREIGN KEY `_MyOrderToOrderItem_A_fkey`;

-- DropForeignKey
ALTER TABLE `_MyOrderToOrderItem` DROP FOREIGN KEY `_MyOrderToOrderItem_B_fkey`;

-- AlterTable
ALTER TABLE `OrderItem` ADD COLUMN `priceOptionId` INTEGER NULL;

-- DropTable
DROP TABLE `_MyOrderToOrderItem`;

-- CreateIndex
CREATE INDEX `OrderItem_priceOptionId_idx` ON `OrderItem`(`priceOptionId`);

-- CreateIndex
CREATE UNIQUE INDEX `OrderItem_orderId_productId_priceOptionId_key` ON `OrderItem`(`orderId`, `productId`, `priceOptionId`);

-- AddForeignKey
ALTER TABLE `OrderItem` ADD CONSTRAINT `OrderItem_priceOptionId_fkey` FOREIGN KEY (`priceOptionId`) REFERENCES `PriceOption`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `OrderItem` ADD CONSTRAINT `OrderItem_orderId_fkey` FOREIGN KEY (`orderId`) REFERENCES `MyOrder`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
