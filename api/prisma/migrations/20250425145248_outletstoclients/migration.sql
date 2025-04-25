/*
  Warnings:

  - Added the required column `address` to the `Clients` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE `Clients` ADD COLUMN `address` VARCHAR(191) NOT NULL,
    ADD COLUMN `balance` VARCHAR(191) NULL,
    ADD COLUMN `email` VARCHAR(191) NULL,
    ADD COLUMN `latitude` DOUBLE NULL,
    ADD COLUMN `longitude` DOUBLE NULL;

-- CreateTable
CREATE TABLE `_ClientsToJourneyPlan` (
    `A` INTEGER NOT NULL,
    `B` INTEGER NOT NULL,

    UNIQUE INDEX `_ClientsToJourneyPlan_AB_unique`(`A`, `B`),
    INDEX `_ClientsToJourneyPlan_B_index`(`B`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `_ClientsToOrder` (
    `A` INTEGER NOT NULL,
    `B` INTEGER NOT NULL,

    UNIQUE INDEX `_ClientsToOrder_AB_unique`(`A`, `B`),
    INDEX `_ClientsToOrder_B_index`(`B`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `_ClientsToProduct` (
    `A` INTEGER NOT NULL,
    `B` INTEGER NOT NULL,

    UNIQUE INDEX `_ClientsToProduct_AB_unique`(`A`, `B`),
    INDEX `_ClientsToProduct_B_index`(`B`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `_ClientsToReport` (
    `A` INTEGER NOT NULL,
    `B` INTEGER NOT NULL,

    UNIQUE INDEX `_ClientsToReport_AB_unique`(`A`, `B`),
    INDEX `_ClientsToReport_B_index`(`B`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `_ClientsToManagerCheckin` (
    `A` INTEGER NOT NULL,
    `B` INTEGER NOT NULL,

    UNIQUE INDEX `_ClientsToManagerCheckin_AB_unique`(`A`, `B`),
    INDEX `_ClientsToManagerCheckin_B_index`(`B`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `_ClientsToJourneyPlan` ADD CONSTRAINT `_ClientsToJourneyPlan_A_fkey` FOREIGN KEY (`A`) REFERENCES `Clients`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToJourneyPlan` ADD CONSTRAINT `_ClientsToJourneyPlan_B_fkey` FOREIGN KEY (`B`) REFERENCES `JourneyPlan`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToOrder` ADD CONSTRAINT `_ClientsToOrder_A_fkey` FOREIGN KEY (`A`) REFERENCES `Clients`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToOrder` ADD CONSTRAINT `_ClientsToOrder_B_fkey` FOREIGN KEY (`B`) REFERENCES `Order`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToProduct` ADD CONSTRAINT `_ClientsToProduct_A_fkey` FOREIGN KEY (`A`) REFERENCES `Clients`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToProduct` ADD CONSTRAINT `_ClientsToProduct_B_fkey` FOREIGN KEY (`B`) REFERENCES `Product`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToReport` ADD CONSTRAINT `_ClientsToReport_A_fkey` FOREIGN KEY (`A`) REFERENCES `Clients`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToReport` ADD CONSTRAINT `_ClientsToReport_B_fkey` FOREIGN KEY (`B`) REFERENCES `Report`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToManagerCheckin` ADD CONSTRAINT `_ClientsToManagerCheckin_A_fkey` FOREIGN KEY (`A`) REFERENCES `Clients`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `_ClientsToManagerCheckin` ADD CONSTRAINT `_ClientsToManagerCheckin_B_fkey` FOREIGN KEY (`B`) REFERENCES `ManagerCheckin`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
