import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { LocaleResolution } from '../../common/locale/locale';
import { parseChannels, parseWith, paginationSchema } from '../../common/validation/query';
import { NewsService } from './news.service';
import {
  NewsChannelDto,
  NewsChannelsResponseDto,
  NewsDetailDto,
  NewsDetailResponseDto,
  NewsListItemDto,
  NewsListResponseDto,
} from './news.types';

@ApiTags('news')
@Controller({ path: 'news', version: '1' })
export class NewsController {
  constructor(private readonly news: NewsService) {}

  @Get('channels')
  @ApiOperation({
    summary: 'List active news channels.',
    description:
      'Channels are fully dynamic. A channel added in the CMS appears here — and therefore in the app — without any code change.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({
    description: 'Active channels ordered by sortOrder, then name.',
    type: NewsChannelsResponseDto,
  })
  async channels(
    @RequestLocale() locale: LocaleResolution,
  ): Promise<ApiResponse<NewsChannelDto[]>> {
    const result = await this.news.getChannels(locale);
    return {
      data: result.data,
      meta: buildMeta({ ...locale, translationFallback: result.translationFallback }),
    };
  }

  @Get()
  @ApiOperation({
    summary: 'List published news articles.',
    description:
      'An absent `channels` parameter means all active channels. A present but empty `channels=` means the user deselected everything and yields an empty list.',
  })
  @ApiQuery({ name: 'channels', required: false, description: 'Comma-separated channel slugs.' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'pageSize', required: false, type: Number, description: 'Max 50.' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: NewsListResponseDto })
  async list(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<NewsListItemDto[]>> {
    const { page, pageSize } = parseWith(paginationSchema, query, locale.resolvedLocale);
    const { channels, channelsParamPresent } = parseChannels(query['channels']);

    const result = await this.news.getNews(locale, {
      channels,
      channelsParamPresent,
      page,
      pageSize,
    });

    return {
      data: result.data,
      meta: buildMeta({
        ...locale,
        translationFallback: result.translationFallback,
        pagination: result.pagination,
      }),
    };
  }

  @Get(':slug')
  @ApiOperation({
    summary: 'Fetch one article by its stable slug.',
    description:
      'Unknown content block types are removed server-side and reported in meta.droppedBlockTypes, so a new CMS block type can never break the detail screen.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: NewsDetailResponseDto })
  async detail(
    @RequestLocale() locale: LocaleResolution,
    @Param('slug') slug: string,
  ): Promise<ApiResponse<NewsDetailDto>> {
    const result = await this.news.getNewsBySlug(locale, slug);
    return {
      data: result.data,
      meta: buildMeta({
        ...locale,
        translationFallback: result.translationFallback,
        droppedBlockTypes: result.droppedBlockTypes,
      }),
    };
  }
}
