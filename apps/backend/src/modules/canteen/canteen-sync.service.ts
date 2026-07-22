import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { CANTEENS, CanteenDefinition } from './canteens.config';
import { CanteenSourceError, MeineMensaClient } from './meine-mensa.client';
import { NormalizedMeal, normalizeDefinitions, normalizeEntry } from './meine-mensa.schema';

/**
 * Canteen synchronisation.
 *
 * THE governing rule of this file: a failed, invalid or unexpectedly empty
 * upstream response must NEVER remove data that is already stored. Stale but
 * real data beats an empty screen, and the user is told the data is stale via
 * `lastSuccessfulSyncAt` / `dataStale`.
 *
 * Concretely:
 *  - transport failure, timeout, malformed body -> record the failure, keep data
 *  - empty `data` array                          -> record `empty`, keep data
 *  - entries for a different location_id         -> reject those entries only
 *  - only a successful, non-empty response may delete anything, and then only
 *    within the date window that was actually confirmed by that response
 */

export type SyncStatus = 'success' | 'empty' | 'failed';

export interface SyncOutcome {
  canteenSlug: string;
  status: SyncStatus;
  recordsReceived: number;
  recordsUpserted: number;
  recordsRejected: number;
  recordsRemoved: number;
  errorMessage?: string;
}

@Injectable()
export class CanteenSyncService {
  private readonly logger = new Logger(CanteenSyncService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly client: MeineMensaClient,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Creates or updates the canteen rows from config. Safe to run repeatedly. */
  async seedCanteens(): Promise<number> {
    for (const canteen of CANTEENS) {
      await this.prisma.canteen.upsert({
        where: { slug: canteen.slug },
        create: {
          slug: canteen.slug,
          sourceLocationId: canteen.sourceLocationId,
          displayNameDe: canteen.displayNameDe,
          displayNameEn: canteen.displayNameEn,
          campusLabelDe: canteen.campusLabelDe,
          campusLabelEn: canteen.campusLabelEn,
          sortOrder: canteen.sortOrder,
          active: canteen.active,
        },
        update: {
          sourceLocationId: canteen.sourceLocationId,
          displayNameDe: canteen.displayNameDe,
          displayNameEn: canteen.displayNameEn,
          campusLabelDe: canteen.campusLabelDe,
          campusLabelEn: canteen.campusLabelEn,
          sortOrder: canteen.sortOrder,
          active: canteen.active,
        },
      });
    }
    return CANTEENS.length;
  }

  private static dateWindow(daysAhead: number, today = new Date()): { from: string; to: string } {
    const from = today.toISOString().slice(0, 10);
    const to = new Date(today.getTime() + daysAhead * 86_400_000).toISOString().slice(0, 10);
    return { from, to };
  }

  async syncAll(): Promise<SyncOutcome[]> {
    await this.seedCanteens();
    const outcomes: SyncOutcome[] = [];

    for (const [index, canteen] of CANTEENS.filter((c) => c.active).entries()) {
      if (index > 0 && this.env.CANTEEN_REQUEST_SPACING_MS > 0) {
        // Be a polite client to a third-party service.
        await new Promise((resolve) => setTimeout(resolve, this.env.CANTEEN_REQUEST_SPACING_MS));
      }
      outcomes.push(await this.syncCanteen(canteen));
    }

    return outcomes;
  }

  async syncCanteen(canteen: CanteenDefinition): Promise<SyncOutcome> {
    const record = await this.prisma.canteen.findUnique({ where: { slug: canteen.slug } });
    if (!record) {
      throw new Error(`Canteen ${canteen.slug} is not seeded`);
    }

    const window = CanteenSyncService.dateWindow(this.env.CANTEEN_SYNC_DAYS_AHEAD);
    const run = await this.prisma.syncRun.create({
      data: { canteenId: record.id, status: 'running' },
    });

    const fail = async (message: string): Promise<SyncOutcome> => {
      await this.prisma.syncRun.update({
        where: { id: run.id },
        data: { status: 'failed', finishedAt: new Date(), errorMessage: message },
      });
      // Deliberately no delete: existing data survives the failure.
      this.logger.warn(`Sync failed for ${canteen.slug}: ${message}; existing data kept`);
      return {
        canteenSlug: canteen.slug,
        status: 'failed',
        recordsReceived: 0,
        recordsUpserted: 0,
        recordsRejected: 0,
        recordsRemoved: 0,
        errorMessage: message,
      };
    };

    let response;
    try {
      response = await this.client.fetchFoodPlans({
        locationId: canteen.sourceLocationId,
        from: window.from,
        to: window.to,
      });
    } catch (error) {
      const message =
        error instanceof CanteenSourceError
          ? `${error.kind}: ${error.message}`
          : 'unexpected source failure';
      return fail(message);
    }

    // Entries for another canteen are a genuine upstream anomaly. Drop them
    // rather than filing another canteen's menu under this one.
    const received = response.data.length;
    const matching = response.data.filter(
      (entry) => entry.location_id === canteen.sourceLocationId,
    );
    const rejected = received - matching.length;
    if (rejected > 0) {
      this.logger.warn(
        `Rejected ${rejected} entr(ies) with a location_id other than ${canteen.sourceLocationId} for ${canteen.slug}`,
      );
    }

    if (matching.length === 0) {
      await this.prisma.syncRun.update({
        where: { id: run.id },
        data: {
          status: 'empty',
          finishedAt: new Date(),
          recordsReceived: received,
          recordsRejected: rejected,
          errorMessage: received > 0 ? 'no entries matched the requested location' : null,
        },
      });
      // An empty answer is NOT a reason to wipe a valid menu.
      this.logger.warn(`Empty result for ${canteen.slug}; existing data kept`);
      return {
        canteenSlug: canteen.slug,
        status: 'empty',
        recordsReceived: received,
        recordsUpserted: 0,
        recordsRejected: rejected,
        recordsRemoved: 0,
      };
    }

    const meals = matching.map(normalizeEntry);
    const definitions = normalizeDefinitions(response.meta);

    let removed = 0;
    try {
      removed = await this.persist(record.id, meals, definitions);
    } catch (error) {
      return fail(
        `persistence failed: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
    }

    await this.prisma.syncRun.update({
      where: { id: run.id },
      data: {
        status: 'success',
        finishedAt: new Date(),
        recordsReceived: received,
        recordsUpserted: meals.length,
        recordsRejected: rejected,
      },
    });

    this.logger.log(
      `Synced ${canteen.slug}: ${meals.length} meal(s) upserted, ${rejected} rejected, ${removed} withdrawn`,
    );

    return {
      canteenSlug: canteen.slug,
      status: 'success',
      recordsReceived: received,
      recordsUpserted: meals.length,
      recordsRejected: rejected,
      recordsRemoved: removed,
    };
  }

  /**
   * Writes a confirmed, non-empty result in a single transaction.
   *
   * Upserts run on the stable `sourcePlanId`, so repeating an import updates
   * instead of duplicating. Removal is limited to the date range the response
   * actually covered: a dish withdrawn upstream disappears, while days outside
   * the confirmed window are left untouched.
   */
  private async persist(
    canteenId: string,
    meals: NormalizedMeal[],
    definitions: Array<{ code: string; labelDe: string; kind: 'ingredient' | 'marker' }>,
  ): Promise<number> {
    const dates = [...new Set(meals.map((meal) => meal.date))].sort();
    const minDate = new Date(`${dates[0]!}T00:00:00.000Z`);
    const maxDate = new Date(`${dates[dates.length - 1]!}T00:00:00.000Z`);
    const keptIds = meals.map((meal) => meal.sourcePlanId);

    return this.prisma.$transaction(async (tx) => {
      for (const definition of definitions) {
        await tx.ingredientDefinition.upsert({
          where: { code: definition.code },
          create: { code: definition.code, labelDe: definition.labelDe, kind: definition.kind },
          // labelEn is never written here — no machine translation.
          update: { labelDe: definition.labelDe, kind: definition.kind },
        });
      }

      for (const meal of meals) {
        const data = {
          canteenId,
          date: new Date(`${meal.date}T00:00:00.000Z`),
          counterId: meal.counterId,
          isSprint: meal.isSprint,
          name: meal.name,
          subtitle: meal.subtitle,
          extras: meal.extras,
          ingredientCodes: meal.ingredientCodes,
          sourceFoodId: meal.sourceFoodId,
        };

        const stored = await tx.meal.upsert({
          where: { sourcePlanId: meal.sourcePlanId },
          create: { sourcePlanId: meal.sourcePlanId, ...data },
          update: data,
        });

        // Replace prices wholesale so a group removed upstream disappears here
        // too, rather than lingering as a stale figure.
        await tx.mealPrice.deleteMany({ where: { mealId: stored.id } });
        if (meal.prices.length > 0) {
          await tx.mealPrice.createMany({
            data: meal.prices.map((price) => ({
              mealId: stored.id,
              group: price.group,
              amount: price.amount,
            })),
          });
        }
      }

      const withdrawn = await tx.meal.deleteMany({
        where: {
          canteenId,
          date: { gte: minDate, lte: maxDate },
          sourcePlanId: { notIn: keptIds },
        },
      });

      return withdrawn.count;
    });
  }

  /** Most recent successful sync, or null if there has never been one. */
  async lastSuccessfulSyncAt(canteenId: string): Promise<Date | null> {
    const run = await this.prisma.syncRun.findFirst({
      where: { canteenId, status: 'success' },
      orderBy: { startedAt: 'desc' },
    });
    return run?.finishedAt ?? null;
  }
}
