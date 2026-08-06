import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { isAllowedMediaType, normaliseMediaPath } from './media.path';

export interface MediaFile {
  body: Buffer;
  contentType: string;
  /** Strapi's own validator, forwarded so clients can revalidate cheaply. */
  etag: string | null;
}

export type MediaFailure = 'not-found' | 'unsupported' | 'too-large' | 'unavailable';

export class MediaError extends Error {
  constructor(public readonly kind: MediaFailure) {
    super(kind);
    this.name = 'MediaError';
  }
}

/**
 * Reads one editorial image from Strapi's upload directory.
 *
 * Why this exists at all: the app must not talk to Strapi (CLAUDE.md §2.1), and
 * Strapi's local provider publishes **relative** URLs, which are useless to a
 * mobile client. So the Campus API serves the bytes itself and publishes its
 * own URL. Strapi's address stays configuration and never reaches a payload.
 *
 * It is deliberately narrow: images only, one directory only, a hard size
 * limit, no redirects. A general-purpose file proxy would be a much larger
 * thing to defend.
 */
@Injectable()
export class MediaService {
  private readonly logger = new Logger(MediaService.name);
  private readonly baseUrl: string;

  /** An editorial image far above this is a mistake, not a photo. */
  static readonly maxBytes = 12 * 1024 * 1024;

  constructor(@Inject(ENV) private readonly env: Env) {
    this.baseUrl = env.STRAPI_BASE_URL.replace(/\/+$/, '');
  }

  async fetch(path: string): Promise<MediaFile> {
    const safe = normaliseMediaPath(path);
    if (safe === null) {
      // Refused before any request is made: the target of a server-side fetch
      // must never be decided by the caller.
      throw new MediaError('not-found');
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.env.STRAPI_TIMEOUT_MS);

    try {
      const response = await fetch(`${this.baseUrl}${safe}`, {
        method: 'GET',
        signal: controller.signal,
        // A redirect could point anywhere; the upload directory has no reason
        // to issue one.
        redirect: 'error',
        headers: { Accept: 'image/*' },
      });

      if (response.status === 404) {
        throw new MediaError('not-found');
      }
      if (!response.ok) {
        throw new MediaError('unavailable');
      }

      const contentType = response.headers.get('content-type');
      if (!isAllowedMediaType(contentType)) {
        throw new MediaError('unsupported');
      }

      const declared = Number(response.headers.get('content-length') ?? '0');
      if (Number.isFinite(declared) && declared > MediaService.maxBytes) {
        throw new MediaError('too-large');
      }

      const body = Buffer.from(await response.arrayBuffer());
      // Checked again: the header is a claim, the body is the fact.
      if (body.byteLength > MediaService.maxBytes) {
        throw new MediaError('too-large');
      }

      return {
        body,
        contentType: contentType as string,
        etag: response.headers.get('etag'),
      };
    } catch (error) {
      if (error instanceof MediaError) {
        throw error;
      }
      // The path is logged, never a token and never the upstream address.
      this.logger.warn(`Media fetch failed (${safe})`);
      throw new MediaError('unavailable');
    } finally {
      clearTimeout(timer);
    }
  }
}
