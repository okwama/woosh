-- CreateTable
CREATE TABLE `leaves` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `userId` INTEGER NOT NULL,
    `leaveType` VARCHAR(191) NOT NULL,
    `startDate` DATETIME(3) NOT NULL,
    `endDate` DATETIME(3) NOT NULL,
    `reason` VARCHAR(191) NOT NULL,
    `attachment` VARCHAR(191) NULL,
    `status` VARCHAR(191) NOT NULL DEFAULT 'PENDING',
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `leaves` ADD CONSTRAINT `leaves_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
