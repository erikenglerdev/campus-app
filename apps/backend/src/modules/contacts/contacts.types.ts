import { ApiProperty } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';
import { ContentBlock } from '../../common/content/content-blocks';
import { RoomReferenceDto } from '../rooms/rooms.types';

/**
 * Public shapes for /v1/contact-areas*.
 *
 * Classes rather than interfaces so the published OpenAPI document carries
 * real response schemas.
 */

export class ContactPersonDto {
  @ApiProperty() name!: string;
  @ApiProperty({ type: String, nullable: true }) role!: string | null;
  @ApiProperty({ type: String, nullable: true }) description!: string | null;
  @ApiProperty({ type: String, nullable: true }) email!: string | null;
  @ApiProperty({ type: String, nullable: true }) phone!: string | null;
  @ApiProperty({ type: String, nullable: true }) website!: string | null;
  @ApiProperty({ type: String, nullable: true }) profileImage!: string | null;
  @ApiProperty() sortOrder!: number;

  @ApiProperty({
    type: [RoomReferenceDto],
    description: 'Rooms of the demo campus map. An empty list is normal — a contact needs no room.',
  })
  rooms!: RoomReferenceDto[];
}

export class ContactAreaListItemDto {
  @ApiProperty({ example: 'studierendenrat' }) slug!: string;
  @ApiProperty() name!: string;
  @ApiProperty() shortDescription!: string;
  @ApiProperty({ example: 'students-council' }) iconKey!: string;
  @ApiProperty() sortOrder!: number;

  @ApiProperty({ type: String, nullable: true }) generalEmail!: string | null;
  @ApiProperty({ type: String, nullable: true }) phone!: string | null;
  @ApiProperty({ type: String, nullable: true }) website!: string | null;
  @ApiProperty({ type: String, nullable: true }) appointmentUrl!: string | null;
  @ApiProperty({ type: String, nullable: true }) address!: string | null;
  @ApiProperty({ type: String, nullable: true }) openingHours!: string | null;

  @ApiProperty({
    description: 'Zero is a valid, fully supported state — an area needs no contact person.',
  })
  personCount!: number;

  @ApiProperty({ description: 'True for seed data that has not been cleared for publication.' })
  isDemoContent!: boolean;
}

export class ContactAreaDetailDto {
  @ApiProperty() slug!: string;
  @ApiProperty() name!: string;
  @ApiProperty() shortDescription!: string;
  @ApiProperty() iconKey!: string;
  @ApiProperty() sortOrder!: number;

  @ApiProperty({ type: String, nullable: true }) generalEmail!: string | null;
  @ApiProperty({ type: String, nullable: true }) phone!: string | null;
  @ApiProperty({ type: String, nullable: true }) website!: string | null;
  @ApiProperty({ type: String, nullable: true }) appointmentUrl!: string | null;
  @ApiProperty({ type: String, nullable: true }) address!: string | null;
  @ApiProperty({ type: String, nullable: true }) openingHours!: string | null;
  @ApiProperty() isDemoContent!: boolean;

  @ApiProperty({
    type: 'array',
    items: { type: 'object', additionalProperties: true },
    description: 'Sanitised content blocks, same rules as news content.',
  })
  description!: ContentBlock[];

  @ApiProperty({ type: [ContactPersonDto], description: 'Active persons only; may be empty.' })
  persons!: ContactPersonDto[];

  @ApiProperty({
    type: [RoomReferenceDto],
    description: 'Rooms of the demo campus map. An empty list is normal — an area needs no room.',
  })
  rooms!: RoomReferenceDto[];
}

export class ContactAreasResponseDto {
  @ApiProperty({ type: [ContactAreaListItemDto] }) data!: ContactAreaListItemDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class ContactAreaDetailResponseDto {
  @ApiProperty({ type: ContactAreaDetailDto }) data!: ContactAreaDetailDto;
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
