import { Module } from '@nestjs/common';
import { AppConfigModule } from './config/app-config.module';
import { PrismaModule } from './prisma/prisma.module';
import { CanteenModule } from './modules/canteen/canteen.module';
import { TimetableModule } from './modules/timetable/timetable.module';

/**
 * Minimal composition for the worker process: configuration, database and the
 * canteen module. No HTTP layer, no Strapi client — the worker never serves
 * requests and never reads editorial content.
 */
@Module({
  imports: [AppConfigModule, PrismaModule, CanteenModule, TimetableModule],
})
export class WorkerModule {}
