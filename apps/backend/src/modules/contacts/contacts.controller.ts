import { Controller, Get, Param } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { LocaleResolution } from '../../common/locale/locale';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { ContactsService } from './contacts.service';
import { ContactAreaDetailDto, ContactAreaListItemDto } from './contacts.types';

@ApiTags('contacts')
@Controller({ path: 'contact-areas', version: '1' })
export class ContactsController {
  constructor(private readonly contacts: ContactsService) {}

  @Get()
  @ApiOperation({
    summary: 'List active contact areas.',
    description:
      'Areas are fully dynamic and are never hardcoded in the client. An area without any contact person is valid and fully usable — `personCount` is then 0.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ description: 'Active areas ordered by sortOrder, then name.' })
  async list(
    @RequestLocale() locale: LocaleResolution,
  ): Promise<ApiResponse<ContactAreaListItemDto[]>> {
    const result = await this.contacts.listAreas(locale);
    return {
      data: result.data,
      meta: buildMeta({ ...locale, translationFallback: result.translationFallback }),
    };
  }

  @Get(':slug')
  @ApiOperation({ summary: 'Fetch one contact area including its active persons.' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  async detail(
    @RequestLocale() locale: LocaleResolution,
    @Param('slug') slug: string,
  ): Promise<ApiResponse<ContactAreaDetailDto>> {
    const result = await this.contacts.getArea(locale, slug);
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
