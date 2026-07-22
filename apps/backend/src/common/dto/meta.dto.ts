import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Locale } from '../locale/locale';

export class PaginationMetaDto {
  @ApiProperty({ example: 1 }) page!: number;
  @ApiProperty({ example: 20 }) pageSize!: number;
  @ApiProperty({ example: 42 }) total!: number;
  @ApiProperty({ example: 3 }) totalPages!: number;
}

export class ResponseMetaDto {
  @ApiProperty({ enum: ['de', 'en'], description: 'Locale the client asked for.' })
  requestedLocale!: Locale;

  @ApiProperty({ enum: ['de', 'en'], description: 'Locale actually served.' })
  resolvedLocale!: Locale;

  @ApiProperty({
    description:
      'True when at least one delivered field came from the German fallback although another locale was requested.',
  })
  translationFallback!: boolean;

  @ApiPropertyOptional({ type: PaginationMetaDto })
  pagination?: PaginationMetaDto;

  @ApiPropertyOptional({
    type: [String],
    description: 'Content block types removed because the MVP client does not render them.',
  })
  droppedBlockTypes?: string[];
}

/** Envelope shared by every content endpoint — see docs/api.md §1. */
export interface ApiResponse<T> {
  data: T;
  meta: ResponseMetaDto;
}

export function buildMeta(input: {
  requestedLocale: Locale;
  resolvedLocale: Locale;
  translationFallback?: boolean;
  pagination?: PaginationMetaDto;
  droppedBlockTypes?: string[];
}): ResponseMetaDto {
  const meta: ResponseMetaDto = {
    requestedLocale: input.requestedLocale,
    resolvedLocale: input.resolvedLocale,
    translationFallback: input.translationFallback ?? false,
  };
  if (input.pagination) {
    meta.pagination = input.pagination;
  }
  if (input.droppedBlockTypes && input.droppedBlockTypes.length > 0) {
    meta.droppedBlockTypes = input.droppedBlockTypes;
  }
  return meta;
}
