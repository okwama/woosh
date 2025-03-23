/*
  Warnings:

  - You are about to drop the column `comment` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `imageUrl` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `productName` on the `Report` table. All the data in the column will be lost.
  - You are about to drop the column `quantity` on the `Report` table. All the data in the column will be lost.
  - You are about to alter the column `type` on the `Report` table. The data in that column could be lost. The data in that column will be cast from `VarChar(191)` to `Enum(EnumId(0))`.

*/
-- AlterTable
ALTER TABLE `Report` DROP COLUMN `comment`,
    DROP COLUMN `imageUrl`,
    DROP COLUMN `productName`,
    DROP COLUMN `quantity`,
    MODIFY `type` ENUM('PRODUCT_AVAILABILITY', 'VISIBILITY_ACTIVITY', 'FEEDBACK') NOT NULL;

-- CreateTable
CREATE TABLE `FeedbackReport` (
    `reportId` INTEGER NOT NULL,
    `comment` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`reportId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `ProductReport` (
    `reportId` INTEGER NOT NULL,
    `productName` VARCHAR(191) NULL,
    `quantity` INTEGER NULL,
    `comment` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`reportId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `VisibilityReport` (
    `reportId` INTEGER NOT NULL,
    `comment` VARCHAR(191) NULL,
    `imageUrl` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`reportId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `FeedbackReport` ADD CONSTRAINT `FeedbackReport_reportId_fkey` FOREIGN KEY (`reportId`) REFERENCES `Report`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `ProductReport` ADD CONSTRAINT `ProductReport_reportId_fkey` FOREIGN KEY (`reportId`) REFERENCES `Report`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `VisibilityReport` ADD CONSTRAINT `VisibilityReport_reportId_fkey` FOREIGN KEY (`reportId`) REFERENCES `Report`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
