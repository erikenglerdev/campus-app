import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';

/**
 * A fully-validated public-calendar definition, as mirrored from Strapi into
 * the operational read-model. `googleCalendarId` is server-internal and is
 * NEVER placed on a DTO.
 */
export interface CalendarDefinition {
  slug: string;
  googleCalendarId: string;
  nameDe: string;
  nameEn: string | null;
  descriptionDe: string | null;
  descriptionEn: string | null;
  colorHex: string;
  iconKey: string;
  sortOrder: number;
  defaultSubscribed: boolean;
  attributionDe: string | null;
  attributionEn: string | null;
  showDescription: boolean;
  showLocation: boolean;
  fallbackTimeZone: string;
}

// --- DTOs -------------------------------------------------------------------

export class PublicCalendarDto {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiProperty() name!: string;
  @ApiPropertyOptional({ nullable: true }) description!: string | null;
  @ApiProperty({ example: '#5B3FD0' }) colorHex!: string;
  @ApiProperty({ example: 'calendar' }) iconKey!: string;
  @ApiProperty() sortOrder!: number;
  @ApiProperty() defaultSubscribed!: boolean;
  @ApiPropertyOptional({ nullable: true }) attribution!: string | null;
  @ApiProperty({ description: 'ready | stale', example: 'ready' }) dataState!: string;
  @ApiPropertyOptional({ nullable: true, type: String, format: 'date-time' })
  lastSuccessfulSyncAt!: string | null;
  @ApiProperty() dataStale!: boolean;
  @ApiProperty({ description: 'Safe HTTPS link to open this calendar in Google Calendar.' })
  googleOpenUrl!: string;
}

export class PublicCalendarEventDto {
  @ApiProperty() id!: string;
  @ApiProperty() calendarId!: string;
  @ApiProperty() calendarSlug!: string;
  @ApiProperty() title!: string;
  @ApiPropertyOptional({ nullable: true }) description!: string | null;
  @ApiPropertyOptional({ nullable: true }) location!: string | null;
  @ApiProperty({ type: String, format: 'date-time' }) start!: string;
  @ApiProperty({ type: String, format: 'date-time' }) end!: string;
  @ApiProperty() allDay!: boolean;
  @ApiProperty({ description: 'confirmed | tentative | cancelled' }) status!: string;
}

export class PublicCalendarListResponseDto {
  @ApiProperty({ type: [PublicCalendarDto] }) data!: PublicCalendarDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class PublicCalendarEventsResponseDto {
  @ApiProperty({ type: [PublicCalendarEventDto] }) data!: PublicCalendarEventDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class GoogleViewUrlDataDto {
  @ApiProperty({ description: 'A calendar.google.com embed URL for the selected calendars.' })
  url!: string;
}

export class GoogleViewUrlResponseDto {
  @ApiProperty({ type: GoogleViewUrlDataDto }) data!: GoogleViewUrlDataDto;
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
