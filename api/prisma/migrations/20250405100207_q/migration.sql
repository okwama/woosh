-- DropIndex
DROP INDEX `OrderItem_orderId_productId_key` ON `OrderItem`;

-- AlterTable
ALTER TABLE `Order` ADD COLUMN `quantity` INTEGER NOT NULL DEFAULT 0;
