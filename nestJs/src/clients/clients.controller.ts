import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
  Query,
  Request,
} from '@nestjs/common';
import { ClientsService } from './clients.service';
import { CreateClientDto } from './dto/create-client.dto';
import { SearchClientsDto } from './dto/search-clients.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('clients')
@UseGuards(JwtAuthGuard)
export class ClientsController {
  constructor(private readonly clientsService: ClientsService) {}

  @Post()
  create(@Body() createClientDto: CreateClientDto) {
    return this.clientsService.create(createClientDto);
  }

  @Get()
  findAll(@Query() searchDto: SearchClientsDto) {
    if (Object.keys(searchDto).length > 0) {
      return this.clientsService.search(searchDto);
    }
    return this.clientsService.findAll();
  }

  @Get('search')
  search(@Query() searchDto: SearchClientsDto) {
    return this.clientsService.search(searchDto);
  }

  @Get('stats')
  getStats(@Query('countryId') countryId?: number, @Query('regionId') regionId?: number) {
    return this.clientsService.getClientStats(countryId, regionId);
  }

  @Get('country/:countryId')
  findByCountry(@Param('countryId') countryId: string) {
    return this.clientsService.findByCountry(+countryId);
  }

  @Get('region/:regionId')
  findByRegion(@Param('regionId') regionId: string) {
    return this.clientsService.findByRegion(+regionId);
  }

  @Get('route/:routeId')
  findByRoute(@Param('routeId') routeId: string) {
    return this.clientsService.findByRoute(+routeId);
  }

  @Get('location')
  findByLocation(
    @Query('latitude') latitude: string,
    @Query('longitude') longitude: string,
    @Query('radius') radius: string = '10',
  ) {
    return this.clientsService.findByLocation(+latitude, +longitude, +radius);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.clientsService.findOne(+id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() updateClientDto: Partial<CreateClientDto>) {
    return this.clientsService.update(+id, updateClientDto);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.clientsService.remove(+id);
  }
} 