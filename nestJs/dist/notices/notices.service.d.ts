import { Repository } from 'typeorm';
import { Notice } from './entities/notice.entity';
import { CreateNoticeDto } from './dto/create-notice.dto';
export declare class NoticesService {
    private noticeRepository;
    constructor(noticeRepository: Repository<Notice>);
    create(createNoticeDto: CreateNoticeDto): Promise<Notice>;
    findAll(): Promise<Notice[]>;
    findOne(id: number): Promise<Notice | null>;
    update(id: number, updateNoticeDto: Partial<CreateNoticeDto>): Promise<Notice | null>;
    remove(id: number): Promise<void>;
}
