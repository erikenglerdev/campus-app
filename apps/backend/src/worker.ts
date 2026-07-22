import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { CronJob } from 'cron';
import { WorkerModule } from './worker.module';
import { JsonLogger } from './common/logger/json-logger.service';
import { ENV } from './config/app-config.module';
import { Env } from './config/env.schema';
import { CanteenSyncService } from './modules/canteen/canteen-sync.service';

/**
 * Canteen synchronisation worker — the second entrypoint of the same image.
 *
 * Runs in its own container so a slow or failing sync cannot affect the API's
 * availability or trigger API restarts. Default schedule: every two hours.
 */
async function bootstrap(): Promise<void> {
  const app = await NestFactory.createApplicationContext(WorkerModule, {
    logger: new JsonLogger(),
  });
  app.enableShutdownHooks();

  const env = app.get<Env>(ENV);
  const sync = app.get(CanteenSyncService);
  const logger = new Logger('CanteenWorker');

  await sync.seedCanteens();

  let running = false;
  const runSync = async (trigger: string): Promise<void> => {
    // Overlap guard: a slow run must not be joined by the next tick.
    if (running) {
      logger.warn(`Skipping ${trigger} run — a synchronisation is still in progress`);
      return;
    }
    running = true;
    try {
      const outcomes = await sync.syncAll();
      for (const outcome of outcomes) {
        logger.log(
          `[${trigger}] ${outcome.canteenSlug}: ${outcome.status} ` +
            `(received=${outcome.recordsReceived} upserted=${outcome.recordsUpserted} ` +
            `rejected=${outcome.recordsRejected} withdrawn=${outcome.recordsRemoved})`,
        );
      }
    } catch (error) {
      // A worker crash would lose the schedule; log and wait for the next tick.
      logger.error(
        `[${trigger}] synchronisation aborted: ${
          error instanceof Error ? error.message : 'unknown error'
        }`,
      );
    } finally {
      running = false;
    }
  };

  const job = new CronJob(env.CANTEEN_SYNC_CRON, () => {
    void runSync('scheduled');
  });
  job.start();

  logger.log(`Canteen worker started with schedule "${env.CANTEEN_SYNC_CRON}"`);

  if (env.CANTEEN_SYNC_ON_BOOT) {
    await runSync('boot');
  }

  const shutdown = (signal: string): void => {
    logger.log(`Received ${signal}, stopping the worker`);
    job.stop();
    void app.close().then(() => process.exit(0));
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

void bootstrap();
