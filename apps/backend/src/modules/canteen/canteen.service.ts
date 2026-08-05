import { Inject, Injectable } from '@nestjs/common';
import { ApiError } from '../../common/errors/api-error';
import { LocaleResolution } from '../../common/locale/locale';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { PrismaService } from '../../prisma/prisma.service';
import { classifyMeal } from './meal-semantics';
import { PRICE_GROUP_LABELS, PriceGroup } from './meine-mensa.schema';
import {
  CanteenListItemDto,
  CanteenMenuDto,
  MealDto,
  MealMarkerDto,
  MealPriceDto,
} from './canteen.types';

/**
 * Read model for /v1/canteens*.
 *
 * Localisation rule for this module, and the reason it differs from news:
 * the upstream source is German-only. Dish names, subtitles, extras and
 * ingredient labels are therefore ALWAYS served as the original German text and
 * marked with `sourceLanguage: "de"`. Nothing here is machine-translated.
 *
 * API-owned strings — canteen names and price group labels — are genuinely
 * bilingual.
 */

const PRICE_GROUP_ORDER: PriceGroup[] = ['student', 'employee', 'guest'];

@Injectable()
export class CanteenService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  private isStale(lastSuccessfulSyncAt: Date | null): boolean {
    if (!lastSuccessfulSyncAt) {
      return true;
    }
    const ageMinutes = (Date.now() - lastSuccessfulSyncAt.getTime()) / 60_000;
    return ageMinutes > this.env.CANTEEN_STALE_AFTER_MINUTES;
  }

  /** Most recent successful sync per canteen, in one query. */
  private async lastSuccessfulByCanteen(canteenIds: string[]): Promise<Map<string, Date>> {
    const runs = await this.prisma.syncRun.findMany({
      where: { canteenId: { in: canteenIds }, status: 'success', finishedAt: { not: null } },
      orderBy: { finishedAt: 'desc' },
      select: { canteenId: true, finishedAt: true },
    });

    const map = new Map<string, Date>();
    for (const run of runs) {
      if (run.canteenId && run.finishedAt && !map.has(run.canteenId)) {
        map.set(run.canteenId, run.finishedAt);
      }
    }
    return map;
  }

  async listCanteens(locale: LocaleResolution): Promise<CanteenListItemDto[]> {
    const canteens = await this.prisma.canteen.findMany({
      where: { active: true },
      orderBy: [{ sortOrder: 'asc' }, { slug: 'asc' }],
    });

    const lastSync = await this.lastSuccessfulByCanteen(canteens.map((c) => c.id));

    return canteens.map((canteen) => {
      const syncedAt = lastSync.get(canteen.id) ?? null;
      return {
        slug: canteen.slug,
        displayName: locale.resolvedLocale === 'en' ? canteen.displayNameEn : canteen.displayNameDe,
        campusLabel: locale.resolvedLocale === 'en' ? canteen.campusLabelEn : canteen.campusLabelDe,
        lastSuccessfulSyncAt: syncedAt ? syncedAt.toISOString() : null,
        dataStale: this.isStale(syncedAt),
      };
    });
  }

  async getMenu(
    locale: LocaleResolution,
    slug: string,
    range: { from: string; to: string },
  ): Promise<{
    menu: CanteenMenuDto;
    lastSuccessfulSyncAt: string | null;
    dataStale: boolean;
  }> {
    const canteen = await this.prisma.canteen.findFirst({ where: { slug, active: true } });
    if (!canteen) {
      throw new ApiError('CANTEEN_NOT_FOUND', locale.resolvedLocale);
    }

    const meals = await this.prisma.meal.findMany({
      where: {
        canteenId: canteen.id,
        date: {
          gte: new Date(`${range.from}T00:00:00.000Z`),
          lte: new Date(`${range.to}T00:00:00.000Z`),
        },
      },
      include: { prices: true },
      orderBy: [{ date: 'asc' }, { counterId: 'asc' }, { name: 'asc' }],
    });

    const definitions = await this.prisma.ingredientDefinition.findMany();
    const definitionByCode = new Map(definitions.map((d) => [d.code, d]));
    // The label is the mapping's fallback when a code is not one of the known
    // ones, so the classifier gets the same dictionary the markers are built
    // from — never a second, drifting copy.
    const labelByCode = new Map(definitions.map((d) => [d.code, d.labelDe]));

    // Every day in the requested range is present, so the client can tell a
    // genuinely empty day apart from a loading error.
    const byDate = new Map<string, MealDto[]>();
    for (
      let cursor = Date.parse(`${range.from}T00:00:00Z`);
      cursor <= Date.parse(`${range.to}T00:00:00Z`);
      cursor += 86_400_000
    ) {
      byDate.set(new Date(cursor).toISOString().slice(0, 10), []);
    }

    for (const meal of meals) {
      const date = meal.date.toISOString().slice(0, 10);
      const markers: MealMarkerDto[] = meal.ingredientCodes.map((code) => {
        const definition = definitionByCode.get(code);
        return {
          code,
          // German label from the source; a code with no definition still
          // renders as the raw code instead of being silently dropped.
          label: definition?.labelDe ?? code,
          kind: definition?.kind === 'marker' ? 'marker' : 'ingredient',
        };
      });

      const prices: MealPriceDto[] = meal.prices
        .map((price) => ({
          group: price.group as PriceGroup,
          label:
            PRICE_GROUP_LABELS[price.group as PriceGroup]?.[locale.resolvedLocale] ?? price.group,
          // Fixed scale so the client never has to guess; formatting is the
          // client's job, arithmetic never happens on this string.
          amount: Number(price.amount).toFixed(2),
          currency: 'EUR' as const,
        }))
        .sort((a, b) => PRICE_GROUP_ORDER.indexOf(a.group) - PRICE_GROUP_ORDER.indexOf(b.group));

      const semantics = classifyMeal({
        ingredientCodes: meal.ingredientCodes,
        isSprint: meal.isSprint,
        labelByCode,
      });

      byDate.get(date)?.push({
        id: String(meal.sourcePlanId),
        name: meal.name,
        subtitle: meal.subtitle,
        // Honest signal: this text was not translated.
        sourceLanguage: 'de',
        counterId: meal.counterId,
        isSprint: meal.isSprint,
        extras: meal.extras,
        markers,
        traits: semantics.traits,
        allergens: semantics.allergens,
        prices,
      });
    }

    const syncedAt = (await this.lastSuccessfulByCanteen([canteen.id])).get(canteen.id) ?? null;

    return {
      menu: {
        canteen: {
          slug: canteen.slug,
          displayName:
            locale.resolvedLocale === 'en' ? canteen.displayNameEn : canteen.displayNameDe,
          campusLabel:
            locale.resolvedLocale === 'en' ? canteen.campusLabelEn : canteen.campusLabelDe,
        },
        days: [...byDate.entries()].map(([date, dayMeals]) => ({ date, meals: dayMeals })),
      },
      lastSuccessfulSyncAt: syncedAt ? syncedAt.toISOString() : null,
      dataStale: this.isStale(syncedAt),
    };
  }
}
