-- CreateTable
CREATE TABLE `Outlet` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(191) NOT NULL,
    `address` VARCHAR(191) NOT NULL,
    `latitude` DOUBLE NULL,
    `longitude` DOUBLE NULL,
    `balance` VARCHAR(191) NULL,
    `email` VARCHAR(191) NULL,
    `kraPin` VARCHAR(191) NULL,
    `phone` VARCHAR(191) NULL,

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- RedefineIndex
CREATE INDEX `OrderItem_productId_fkey` ON `OrderItem`(`productId`);
DROP INDEX `OrderItem_productId_idx` ON `OrderItem`;

-- RedefineIndex
CREATE INDEX `Product_clientId_fkey` ON `Product`(`clientId`);
DROP INDEX `Product_clientId_idx` ON `Product`;

-- RedefineIndex
CREATE INDEX `Report_journeyPlanId_fkey` ON `Report`(`journeyPlanId`);
DROP INDEX `Report_journeyPlanId_idx` ON `Report`;

-- RedefineIndex
CREATE INDEX `Report_orderId_fkey` ON `Report`(`orderId`);
DROP INDEX `Report_orderId_idx` ON `Report`;

-- RedefineIndex
CREATE INDEX `Report_userId_fkey` ON `Report`(`userId`);
DROP INDEX `Report_userId_idx` ON `Report`;
