/*
  Warnings:

  - You are about to drop the column `region` on the `users` table. All the data in the column will be lost.
  - You are about to drop the column `regionId` on the `users` table. All the data in the column will be lost.
  - Added the required column `regionsId` to the `users` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE `users` DROP COLUMN `region`,
    DROP COLUMN `regionId`,
    ADD COLUMN `regionsId` INTEGER NOT NULL;

-- AddForeignKey
ALTER TABLE `users` ADD CONSTRAINT `users_regionsId_fkey` FOREIGN KEY (`regionsId`) REFERENCES `Regions`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
