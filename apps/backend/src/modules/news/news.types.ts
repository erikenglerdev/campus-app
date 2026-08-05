import { ApiProperty } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';
import { ContentBlock } from '../../common/content/content-blocks';

/**
 * Public shapes returned by /v1/news*.
 *
 * These are classes rather than interfaces so the generated OpenAPI document
 * carries real response schemas — an interface is erased at compile time and
 * would leave the published contract without any payload description.
 *
 * Strapi's `documentId`, `localizations` and `formats` stop at the mapper and
 * never appear here.
 */

export class ImageDto {
  @ApiProperty({ example: 'https://cdn.example/hero.jpg', description: 'Always https.' })
  url!: string;

  @ApiProperty({ type: String, nullable: true })
  alternativeText!: string | null;

  @ApiProperty({ type: Number, nullable: true })
  width!: number | null;

  @ApiProperty({ type: Number, nullable: true })
  height!: number | null;
}

export class NewsChannelDto {
  @ApiProperty({ example: 'campus-news', description: 'Stable, never localised.' })
  slug!: string;

  @ApiProperty({ example: 'Campus News' })
  name!: string;

  @ApiProperty({ type: String, nullable: true })
  description!: string | null;

  @ApiProperty({ example: 'campus', description: 'Semantic key, not a client class name.' })
  iconKey!: string;

  @ApiProperty({ example: '#5B3FD0', pattern: '^#[0-9A-Fa-f]{6}$' })
  colorHex!: string;

  @ApiProperty({ example: 10 })
  sortOrder!: number;

  @ApiProperty({
    description: 'Applied by the client exactly once, when the slug first appears.',
  })
  defaultSubscribed!: boolean;
}

export class NewsChannelRefDto {
  @ApiProperty() slug!: string;
  @ApiProperty() name!: string;
  @ApiProperty() colorHex!: string;
}

export class AuthorDto {
  @ApiProperty() name!: string;
  @ApiProperty({ type: String, nullable: true }) role!: string | null;
}

export class NewsListItemDto {
  @ApiProperty({ example: 'semesterstart-2026' }) slug!: string;
  @ApiProperty() title!: string;
  @ApiProperty() teaser!: string;

  @ApiProperty({ type: String, nullable: true, format: 'date-time' })
  publishedAt!: string | null;

  @ApiProperty() isPinned!: boolean;

  @ApiProperty({ type: ImageDto, nullable: true })
  heroImage!: ImageDto | null;

  @ApiProperty({ type: [NewsChannelRefDto] })
  channels!: NewsChannelRefDto[];

  @ApiProperty({ type: [AuthorDto] })
  authors!: AuthorDto[];

  @ApiProperty({ type: String, nullable: true })
  sourceName!: string | null;

  @ApiProperty({
    type: String,
    nullable: true,
    description: 'Validated https URL of the original source, or null.',
  })
  sourceUrl!: string | null;

  @ApiProperty({
    type: 'array',
    items: { type: 'object', additionalProperties: true },
    description:
      'Sanitised content blocks, delivered with the LIST entry so a feed can render the article inline without a request per card. Only paragraph, heading, list, quote and image survive; anything else is removed server-side and reported in meta.droppedBlockTypes.',
  })
  content!: ContentBlock[];
}

/**
 * Identical to the list entry.
 *
 * The detail endpoint stays for compatibility; it no longer carries anything
 * the list does not.
 */
export class NewsDetailDto extends NewsListItemDto {}

// --- Response envelopes ------------------------------------------------------

export class NewsChannelsResponseDto {
  @ApiProperty({ type: [NewsChannelDto] }) data!: NewsChannelDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class NewsListResponseDto {
  @ApiProperty({ type: [NewsListItemDto] }) data!: NewsListItemDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class NewsDetailResponseDto {
  @ApiProperty({ type: NewsDetailDto }) data!: NewsDetailDto;
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
