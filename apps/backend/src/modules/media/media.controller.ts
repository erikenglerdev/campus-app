import { Controller, Get, Header, Param, Res } from '@nestjs/common';
import { ApiOperation, ApiParam, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { ApiError } from '../../common/errors/api-error';
import { MediaError, MediaService } from './media.service';

/**
 * Serves editorial images.
 *
 * The one endpoint of this API that answers with bytes rather than JSON, and
 * the reason the app never has to know Strapi's address: contact photos and
 * news banners are published as `/v1/media/uploads/…` and fetched from the
 * Campus API like everything else (CLAUDE.md §2.1).
 */
@ApiTags('media')
@Controller({ path: 'media', version: '1' })
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Get('uploads/:filename')
  @ApiOperation({
    summary: 'An editorial image from the CMS.',
    description:
      'Images only, from the CMS upload directory only. The path is validated against a strict ' +
      'allowlist before anything is fetched, so it cannot be pointed at another target. Cached ' +
      'for a day: editorial images are replaced by uploading a new file, which changes the name.',
  })
  @ApiParam({ name: 'filename', example: 'foto_5a141d3978.jpeg' })
  @Header('Cache-Control', 'public, max-age=86400')
  // Belt and braces for a byte-serving endpoint: nothing here should ever be
  // interpreted as a document by a client that guesses at content types.
  @Header('X-Content-Type-Options', 'nosniff')
  @Header('Content-Disposition', 'inline')
  async get(@Param('filename') filename: string, @Res() response: Response): Promise<void> {
    try {
      const file = await this.media.fetch(`/uploads/${filename}`);
      response.setHeader('Content-Type', file.contentType);
      if (file.etag) {
        response.setHeader('ETag', file.etag);
      }
      response.send(file.body);
    } catch (error) {
      throw MediaController.toApiError(error);
    }
  }

  private static toApiError(error: unknown): ApiError {
    if (!(error instanceof MediaError)) {
      return new ApiError('UPSTREAM_UNAVAILABLE');
    }
    switch (error.kind) {
      case 'not-found':
      case 'unsupported':
        // Deliberately the same answer: whether a path is outside the
        // allowlist, holds a PDF or simply does not exist is nobody's
        // business, and distinguishing them would map out the upload
        // directory for anyone who asks often enough.
        return new ApiError('MEDIA_NOT_FOUND');
      case 'too-large':
      case 'unavailable':
        return new ApiError('UPSTREAM_UNAVAILABLE');
    }
  }
}
