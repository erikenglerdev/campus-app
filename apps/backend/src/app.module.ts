import { Module } from '@nestjs/common';
import { AppConfigModule } from './config/app-config.module';
import { PrismaModule } from './prisma/prisma.module';
import { CanteenModule } from './modules/canteen/canteen.module';
import { ContactsModule } from './modules/contacts/contacts.module';
import { HealthModule } from './modules/health/health.module';
import { NewsModule } from './modules/news/news.module';
import { StrapiModule } from './modules/strapi/strapi.module';

/**
 * HTTP API composition.
 *
 * The scheduler is deliberately NOT registered here — synchronisation runs in
 * the separate worker entrypoint (src/worker.ts) so a slow or failing sync can
 * never block the API or cause it to restart.
 */
@Module({
  imports: [
    AppConfigModule,
    PrismaModule,
    StrapiModule,
    HealthModule,
    NewsModule,
    ContactsModule,
    CanteenModule,
  ],
})
export class AppModule {}
