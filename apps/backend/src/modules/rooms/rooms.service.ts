import { Injectable } from '@nestjs/common';
import { ApiError } from '../../common/errors/api-error';
import { Locale, LocaleResolution } from '../../common/locale/locale';
import { asString } from '../../common/util/coerce';
import { StrapiClient, StrapiListResponse, StrapiRequestError } from '../strapi/strapi.client';
import { RoomDto, RoomReferenceDto } from './rooms.types';

/**
 * Read model for /v1/rooms*.
 *
 * The `room` collection is NOT a localised Strapi content type: a room is one
 * physical thing, so it carries explicit `…De`/`…En` field pairs instead of one
 * document per locale. That makes the locale contract a field selection rather
 * than the document overlay news and contacts need — with the same outcome:
 * German is canonical, and anything without an English text is served as German
 * with `translationFallback: true` instead of being machine-translated.
 *
 * Only rooms that are BOTH catalogue-active and editorially visible are served.
 */

const ROOMS_PATH = '/api/rooms';

/** Fields the public API needs. Relations are deliberately not populated. */
const ROOM_FIELDS = [
  'roomKey',
  'roomNumber',
  'buildingKey',
  'buildingNameDe',
  'buildingNameEn',
  'floorKey',
  'floorLevel',
  'floorNameDe',
  'floorNameEn',
  'roomType',
  'displayNameDe',
  'displayNameEn',
  'descriptionDe',
  'descriptionEn',
  'mapVersion',
  'sortOrder',
] as const;

/**
 * Fields a populated room relation needs.
 *
 * `catalogActive` and `isVisible` are included so the same visibility contract
 * that guards /v1/rooms also applies to a room reached through a relation.
 */
export const ROOM_REFERENCE_FIELDS = [
  'roomKey',
  'roomNumber',
  'buildingKey',
  'buildingNameDe',
  'buildingNameEn',
  'floorKey',
  'floorLevel',
  'floorNameDe',
  'floorNameEn',
  'displayNameDe',
  'displayNameEn',
  'catalogActive',
  'isVisible',
] as const;

type Raw = Record<string, unknown>;

export interface RoomFilters {
  buildingKey?: string;
  floorKey?: string;
}

function isRecord(value: unknown): value is Raw {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

function int(value: unknown, fallback = 0): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}

/**
 * Picks the localised variant and reports whether German had to stand in.
 * A field that is empty in BOTH locales is simply absent, not a fallback.
 */
function localised(
  raw: Raw,
  base: string,
  locale: Locale,
): { value: string | null; fallback: boolean } {
  const german = str(raw[`${base}De`]);
  if (locale === 'de') {
    return { value: german, fallback: false };
  }
  const english = str(raw[`${base}En`]);
  if (english) {
    return { value: english, fallback: false };
  }
  return { value: german, fallback: german !== null };
}

@Injectable()
export class RoomsService {
  constructor(private readonly strapi: StrapiClient) {}

  private async fetch(query: Record<string, unknown>): Promise<Raw[]> {
    try {
      const response = await this.strapi.get<StrapiListResponse<Raw>>(ROOMS_PATH, query);
      return Array.isArray(response?.data) ? response.data : [];
    } catch (error) {
      if (error instanceof StrapiRequestError) {
        throw new ApiError(error.kind === 'timeout' ? 'UPSTREAM_TIMEOUT' : 'UPSTREAM_UNAVAILABLE');
      }
      throw error;
    }
  }

  /** The public visibility contract, applied to every query without exception. */
  private static baseFilters(filters: RoomFilters = {}): Record<string, unknown> {
    const built: Record<string, unknown> = {
      catalogActive: { $eq: true },
      isVisible: { $eq: true },
    };
    if (filters.buildingKey) built.buildingKey = { $eq: filters.buildingKey };
    if (filters.floorKey) built.floorKey = { $eq: filters.floorKey };
    return built;
  }

  private static map(raw: Raw, locale: Locale): { room: RoomDto; fallback: boolean } | null {
    const roomKey = str(raw['roomKey']);
    if (!roomKey) return null;

    const building = localised(raw, 'buildingName', locale);
    const floor = localised(raw, 'floorName', locale);
    const displayName = localised(raw, 'displayName', locale);
    const description = localised(raw, 'description', locale);

    return {
      room: {
        roomKey,
        roomNumber: asString(raw['roomNumber']),
        buildingKey: asString(raw['buildingKey']),
        buildingName: building.value ?? asString(raw['buildingKey']),
        floorKey: asString(raw['floorKey']),
        floorLevel: int(raw['floorLevel']),
        floorName: floor.value ?? '',
        roomType: asString(raw['roomType'], 'office'),
        displayName: displayName.value,
        description: description.value,
        mapVersion: asString(raw['mapVersion']),
        sortOrder: int(raw['sortOrder']),
      },
      fallback: building.fallback || floor.fallback || displayName.fallback || description.fallback,
    };
  }

  private static sort(rooms: RoomDto[]): RoomDto[] {
    return rooms.sort(
      (a, b) => a.sortOrder - b.sortOrder || a.roomNumber.localeCompare(b.roomNumber),
    );
  }

  async listRooms(
    locale: LocaleResolution,
    filters: RoomFilters,
  ): Promise<{ data: RoomDto[]; translationFallback: boolean }> {
    const rows = await this.fetch({
      filters: RoomsService.baseFilters(filters),
      fields: [...ROOM_FIELDS],
      sort: ['sortOrder:asc', 'roomNumber:asc'],
      // The demo catalogue is small and the client searches locally, so the
      // whole catalogue is served in one bounded response.
      pagination: { pageSize: 500 },
    });

    let translationFallback = false;
    const data: RoomDto[] = [];
    for (const raw of rows) {
      if (!isRecord(raw)) continue;
      const mapped = RoomsService.map(raw, locale.resolvedLocale);
      if (!mapped) continue;
      if (mapped.fallback) translationFallback = true;
      data.push(mapped.room);
    }

    return { data: RoomsService.sort(data), translationFallback };
  }

  async getRoom(
    locale: LocaleResolution,
    roomKey: string,
  ): Promise<{ data: RoomDto; translationFallback: boolean }> {
    const rows = await this.fetch({
      filters: { ...RoomsService.baseFilters(), roomKey: { $eq: roomKey } },
      fields: [...ROOM_FIELDS],
      pagination: { pageSize: 1 },
    });

    const raw = rows[0];
    const mapped = isRecord(raw) ? RoomsService.map(raw, locale.resolvedLocale) : null;
    if (!mapped) {
      throw new ApiError('ROOM_NOT_FOUND', locale.resolvedLocale);
    }

    return { data: mapped.room, translationFallback: mapped.fallback };
  }
}

/**
 * Maps a populated room relation to compact references.
 *
 * Shared with the contacts module so a room line renders identically wherever
 * it appears. An empty or absent relation yields an empty list — a contact
 * without a room stays fully valid.
 */
export function mapRoomReferences(
  value: unknown,
  locale: Locale,
): { rooms: RoomReferenceDto[]; fallback: boolean } {
  if (!Array.isArray(value)) {
    return { rooms: [], fallback: false };
  }

  let fallback = false;
  const rooms: RoomReferenceDto[] = [];

  for (const entry of value) {
    if (!isRecord(entry)) continue;
    // Invisible or deactivated rooms must not leak through a relation either.
    if (entry['catalogActive'] === false || entry['isVisible'] === false) continue;

    const roomKey = str(entry['roomKey']);
    if (!roomKey) continue;

    const building = localised(entry, 'buildingName', locale);
    const floor = localised(entry, 'floorName', locale);
    const displayName = localised(entry, 'displayName', locale);
    if (building.fallback || floor.fallback || displayName.fallback) fallback = true;

    rooms.push({
      roomKey,
      roomNumber: asString(entry['roomNumber']),
      buildingKey: asString(entry['buildingKey']),
      buildingName: building.value ?? asString(entry['buildingKey']),
      floorKey: asString(entry['floorKey']),
      floorLevel: int(entry['floorLevel']),
      floorName: floor.value ?? '',
      displayName: displayName.value,
    });
  }

  rooms.sort((a, b) => a.roomNumber.localeCompare(b.roomNumber));
  return { rooms, fallback };
}
