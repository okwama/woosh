-- DropForeignKey
ALTER TABLE `users` DROP FOREIGN KEY `users_regionsId_fkey`;

-- AlterTable
ALTER TABLE `users` MODIFY `regionsId` INTEGER NULL;

-- AddForeignKey
ALTER TABLE `users` ADD CONSTRAINT `users_regionsId_fkey` FOREIGN KEY (`regionsId`) REFERENCES `Regions`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
