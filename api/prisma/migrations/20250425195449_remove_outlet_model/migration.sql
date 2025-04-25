/*
  Warnings:

  - You are about to drop the column `outletId` on the `JourneyPlan` table. All the data in the column will be lost.
  - You are about to drop the column `outletId` on the `ManagerCheckin` table. All the data in the column will be lost.
  - You are about to drop the column `outletId` on the `Order` table. All the data in the column will be lost.
  - You are about to drop the column `outletId` on the `Product` table. All the data in the column will be lost.
  - You are about to drop the column `outletId` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the `MyOrder` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `Outlet` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `_ClientsToJourneyPlan` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `_ClientsToManagerCheckin` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `_ClientsToOrder` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `_ClientsToProduct` table. If the table is not empty, all the data it contains will be lost.
  - You are about to drop the `_ClientsToReport` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `clientId` to the `JourneyPlan` table without a default value. This is not possible if the table is not empty.
  - Added the required column `clientId` to the `ManagerCheckin` table without a default value. This is not possible if the table is not empty.
  - Added the required column `clientId` to the `Order` table without a default value. This is not possible if the table is not empty.
  - Added the required column `clientId` to the `Report` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE `JourneyPlan` DROP FOREIGN KEY `JourneyPlan_outletId_fkey`;

-- DropForeignKey
ALTER TABLE `ManagerCheckin` DROP FOREIGN KEY `ManagerCheckin_outletId_fkey`;

-- DropForeignKey
ALTER TABLE `Order` DROP FOREIGN KEY `Order_outletId_fkey`;

-- DropForeignKey
ALTER TABLE `OrderItem` DROP FOREIGN KEY `OrderItem_orderId_fkey`;

-- DropForeignKey
ALTER TABLE `OrderItem` DROP FOREIGN KEY `OrderItem_productId_fkey`;

-- DropForeignKey
ALTER TABLE `Product` DROP FOREIGN KEY `Product_outletId_fkey`;

-- DropForeignKey
ALTER TABLE `Report` DROP FOREIGN KEY `Report_outletId_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToJourneyPlan` DROP FOREIGN KEY `_ClientsToJourneyPlan_A_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToJourneyPlan` DROP FOREIGN KEY `_ClientsToJourneyPlan_B_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToManagerCheckin` DROP FOREIGN KEY `_ClientsToManagerCheckin_A_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToManagerCheckin` DROP FOREIGN KEY `_ClientsToManagerCheckin_B_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToOrder` DROP FOREIGN KEY `_ClientsToOrder_A_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToOrder` DROP FOREIGN KEY `_ClientsToOrder_B_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToProduct` DROP FOREIGN KEY `_ClientsToProduct_A_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToProduct` DROP FOREIGN KEY `_ClientsToProduct_B_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToReport` DROP FOREIGN KEY `_ClientsToReport_A_fkey`;

-- DropForeignKey
ALTER TABLE `_ClientsToReport` DROP FOREIGN KEY `_ClientsToReport_B_fkey`;

-- AlterTable
ALTER TABLE `JourneyPlan` DROP COLUMN `outletId`,
    ADD COLUMN `clientId` INTEGER NOT NULL;

-- AlterTable
ALTER TABLE `ManagerCheckin` DROP COLUMN `outletId`,
    ADD COLUMN `clientId` INTEGER NOT NULL;

-- AlterTable
ALTER TABLE `Order` DROP COLUMN `outletId`,
    ADD COLUMN `clientId` INTEGER NOT NULL;

-- AlterTable
ALTER TABLE `Product` DROP COLUMN `outletId`,
    ADD COLUMN `clientId` INTEGER NULL;

-- AlterTable
ALTER TABLE `Report` DROP COLUMN `outletId`,
    ADD COLUMN `clientId` INTEGER NOT NULL;

-- DropTable
DROP TABLE `MyOrder`;

-- DropTable
DROP TABLE `Outlet`;

-- DropTable
DROP TABLE `_ClientsToJourneyPlan`;

-- DropTable
DROP TABLE `_ClientsToManagerCheckin`;

-- DropTable
DROP TABLE `_ClientsToOrder`;

-- DropTable
DROP TABLE `_ClientsToProduct`;

-- DropTable
DROP TABLE `_ClientsToReport`;

-- CreateIndex
CREATE INDEX `JourneyPlan_clientId_idx` ON `JourneyPlan`(`clientId`);

-- CreateIndex
CREATE INDEX `ManagerCheckin_clientId_idx` ON `ManagerCheckin`(`clientId`);

-- CreateIndex
CREATE INDEX `Order_clientId_idx` ON `Order`(`clientId`);

-- CreateIndex
CREATE INDEX `Product_clientId_idx` ON `Product`(`clientId`);

-- CreateIndex
CREATE INDEX `Report_clientId_idx` ON `Report`(`clientId`);

-- AddForeignKey
ALTER TABLE `ManagerCheckin` ADD CONSTRAINT `ManagerCheckin_clientId_fkey` FOREIGN KEY (`clientId`) REFERENCES `Clients`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Order` ADD CONSTRAINT `Order_clientId_fkey` FOREIGN KEY (`clientId`) REFERENCES `Clients`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `OrderItem` ADD CONSTRAINT `OrderItem_orderId_fkey` FOREIGN KEY (`orderId`) REFERENCES `Order`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `OrderItem` ADD CONSTRAINT `OrderItem_productId_fkey` FOREIGN KEY (`productId`) REFERENCES `Product`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `JourneyPlan` ADD CONSTRAINT `JourneyPlan_clientId_fkey` FOREIGN KEY (`clientId`) REFERENCES `Clients`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Report` ADD CONSTRAINT `Report_clientId_fkey` FOREIGN KEY (`clientId`) REFERENCES `Clients`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Product` ADD CONSTRAINT `Product_clientId_fkey` FOREIGN KEY (`clientId`) REFERENCES `Clients`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- RedefineIndex
CREATE INDEX `JourneyPlan_userId_idx` ON `JourneyPlan`(`userId`);
DROP INDEX `JourneyPlan_userId_fkey` ON `JourneyPlan`;

-- RedefineIndex
CREATE INDEX `Order_userId_idx` ON `Order`(`userId`);
DROP INDEX `Order_userId_fkey` ON `Order`;

-- RedefineIndex
CREATE INDEX `OrderItem_orderId_idx` ON `OrderItem`(`orderId`);
DROP INDEX `OrderItem_orderId_fkey` ON `OrderItem`;

-- RedefineIndex
CREATE INDEX `OrderItem_productId_idx` ON `OrderItem`(`productId`);
DROP INDEX `OrderItem_productId_fkey` ON `OrderItem`;

-- RedefineIndex
CREATE INDEX `Report_journeyPlanId_idx` ON `Report`(`journeyPlanId`);
DROP INDEX `Report_journeyPlanId_fkey` ON `Report`;

-- RedefineIndex
CREATE INDEX `Report_orderId_idx` ON `Report`(`orderId`);
DROP INDEX `Report_orderId_fkey` ON `Report`;

-- RedefineIndex
CREATE INDEX `Report_userId_idx` ON `Report`(`userId`);
DROP INDEX `Report_userId_fkey` ON `Report`;
