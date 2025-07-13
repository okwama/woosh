import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async findByEmail(email: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { email, status: 1 }, // Active users only
    });
  }

  async findByPhoneNumber(phoneNumber: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { phone: phoneNumber, status: 1 }, // Active users only
    });
  }

  async findById(id: number): Promise<User | null> {
    return this.userRepository.findOne({
      where: { id, status: 1 }, // Active users only
    });
  }

  async findAll(): Promise<User[]> {
    return this.userRepository.find({
      where: { status: 1 }, // Active users only
    });
  }

  async create(userData: Partial<User>): Promise<User> {
    const user = this.userRepository.create(userData);
    return this.userRepository.save(user);
  }

  async update(id: number, userData: Partial<User>): Promise<User | null> {
    await this.userRepository.update(id, userData);
    return this.findById(id);
  }

  async delete(id: number): Promise<void> {
    await this.userRepository.update(id, { status: 0 }); // Soft delete
  }

  async findByCountryAndRegion(countryId: number, regionId: number): Promise<User[]> {
    return this.userRepository.find({
      where: { countryId, regionId, status: 1 },
    });
  }

  async findByRoute(routeId: number): Promise<User[]> {
    return this.userRepository.find({
      where: { routeId, status: 1 },
    });
  }
} 