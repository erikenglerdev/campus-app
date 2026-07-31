import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';

/**
 * Public shapes for /v1/rooms*.
 *
 * The room catalogue describes a FICTIONAL demonstration campus map. Nothing
 * here refers to a real building or room, and the DTO carries no Strapi
 * internals: clients only ever see the stable `roomKey`.
 */

export class RoomDto {
  @ApiProperty({ example: 'demo-north-level2-b201' }) roomKey!: string;
  @ApiProperty({ example: 'B.201' }) roomNumber!: string;

  @ApiProperty({ example: 'demo-north' }) buildingKey!: string;
  @ApiProperty({ description: 'Localised building name.' }) buildingName!: string;

  @ApiProperty({ example: 'demo-north-level2' }) floorKey!: string;
  @ApiProperty({ example: 2 }) floorLevel!: number;
  @ApiProperty({ description: 'Localised floor name.' }) floorName!: string;

  @ApiProperty({
    enum: ['lecture', 'seminar', 'office', 'lab', 'meeting', 'service'],
    description: 'Stable technical key; the client renders a localised label.',
  })
  roomType!: string;

  @ApiPropertyOptional({ type: String, nullable: true, description: 'Localised display name.' })
  displayName!: string | null;

  @ApiPropertyOptional({ type: String, nullable: true, description: 'Localised description.' })
  description!: string | null;

  @ApiProperty({
    example: 'demo-north-2026-07-31',
    description: 'Version of the map catalogue this room belongs to.',
  })
  mapVersion!: string;

  @ApiProperty() sortOrder!: number;
}

/**
 * A compact reference used by contact DTOs.
 *
 * Carries enough to render a readable line AND to deep-link into the campus
 * map, but never a Strapi id.
 */
export class RoomReferenceDto {
  @ApiProperty({ example: 'demo-north-level2-b201' }) roomKey!: string;
  @ApiProperty({ example: 'B.201' }) roomNumber!: string;
  @ApiProperty({ example: 'demo-north' }) buildingKey!: string;
  @ApiProperty({ description: 'Localised building name.' }) buildingName!: string;
  @ApiProperty({ example: 'demo-north-level2' }) floorKey!: string;
  @ApiProperty({ example: 2 }) floorLevel!: number;
  @ApiProperty({ description: 'Localised floor name.' }) floorName!: string;
  @ApiPropertyOptional({ type: String, nullable: true }) displayName!: string | null;
}

export class RoomsResponseDto {
  @ApiProperty({ type: [RoomDto] }) data!: RoomDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class RoomResponseDto {
  @ApiProperty({ type: RoomDto }) data!: RoomDto;
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
