/*
  Warnings:

  - You are about to drop the `User` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE `JourneyPlan` DROP FOREIGN KEY `JourneyPlan_userId_fkey`;

-- DropForeignKey
ALTER TABLE `Order` DROP FOREIGN KEY `Order_userId_fkey`;

-- DropForeignKey
ALTER TABLE `Report` DROP FOREIGN KEY `Report_userId_fkey`;

-- DropForeignKey
ALTER TABLE `Token` DROP FOREIGN KEY `Token_userId_fkey`;

-- DropForeignKey
ALTER TABLE `leaves` DROP FOREIGN KEY `leaves_userId_fkey`;

-- DropTable
DROP TABLE `User`;

-- CreateTable
CREATE TABLE `users` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(191) NOT NULL,
    `email` VARCHAR(191) NOT NULL,
    `phoneNumber` VARCHAR(191) NOT NULL,
    `password` VARCHAR(191) NOT NULL,
    `role` VARCHAR(191) NOT NULL DEFAULT 'USER',
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    UNIQUE INDEX `users_email_key`(`email`),
    UNIQUE INDEX `users_phoneNumber_key`(`phoneNumber`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `Token` ADD CONSTRAINT `Token_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Order` ADD CONSTRAINT `Order_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `JourneyPlan` ADD CONSTRAINT `JourneyPlan_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Report` ADD CONSTRAINT `Report_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `leaves` ADD CONSTRAINT `leaves_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
