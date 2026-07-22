import { HttpException, HttpStatus } from '@nestjs/common';
import { Locale } from '../locale/locale';

/**
 * Public error contract — see docs/api.md §3.
 *
 * Every message is bilingual and written for an end user. Internal details,
 * stack traces, upstream URLs and tokens never appear in a response body.
 */

export type ApiErrorCode =
  | 'VALIDATION_FAILED'
  | 'UNSUPPORTED_LOCALE'
  | 'NEWS_ARTICLE_NOT_FOUND'
  | 'CONTACT_AREA_NOT_FOUND'
  | 'CANTEEN_NOT_FOUND'
  | 'UPSTREAM_UNAVAILABLE'
  | 'UPSTREAM_TIMEOUT'
  | 'INTERNAL_ERROR';

type Messages = Record<Locale, string>;

const MESSAGES: Record<ApiErrorCode, Messages> = {
  VALIDATION_FAILED: {
    de: 'Die Anfrage enthält ungültige Parameter.',
    en: 'The request contains invalid parameters.',
  },
  UNSUPPORTED_LOCALE: {
    de: 'Die angeforderte Sprache wird nicht unterstützt. Unterstützt werden „de“ und „en“.',
    en: 'The requested locale is not supported. Supported locales are "de" and "en".',
  },
  NEWS_ARTICLE_NOT_FOUND: {
    de: 'Der angeforderte Beitrag wurde nicht gefunden.',
    en: 'The requested article was not found.',
  },
  CONTACT_AREA_NOT_FOUND: {
    de: 'Der angeforderte Kontaktbereich wurde nicht gefunden.',
    en: 'The requested contact area was not found.',
  },
  CANTEEN_NOT_FOUND: {
    de: 'Die angeforderte Mensa wurde nicht gefunden.',
    en: 'The requested canteen was not found.',
  },
  UPSTREAM_UNAVAILABLE: {
    de: 'Die Inhalte sind derzeit nicht verfügbar. Bitte später erneut versuchen.',
    en: 'Content is currently unavailable. Please try again later.',
  },
  UPSTREAM_TIMEOUT: {
    de: 'Die Anfrage hat zu lange gedauert. Bitte später erneut versuchen.',
    en: 'The request took too long. Please try again later.',
  },
  INTERNAL_ERROR: {
    de: 'Es ist ein unerwarteter Fehler aufgetreten.',
    en: 'An unexpected error occurred.',
  },
};

const STATUS: Record<ApiErrorCode, HttpStatus> = {
  VALIDATION_FAILED: HttpStatus.BAD_REQUEST,
  UNSUPPORTED_LOCALE: HttpStatus.BAD_REQUEST,
  NEWS_ARTICLE_NOT_FOUND: HttpStatus.NOT_FOUND,
  CONTACT_AREA_NOT_FOUND: HttpStatus.NOT_FOUND,
  CANTEEN_NOT_FOUND: HttpStatus.NOT_FOUND,
  UPSTREAM_UNAVAILABLE: HttpStatus.SERVICE_UNAVAILABLE,
  UPSTREAM_TIMEOUT: HttpStatus.GATEWAY_TIMEOUT,
  INTERNAL_ERROR: HttpStatus.INTERNAL_SERVER_ERROR,
};

export function messageFor(code: ApiErrorCode, locale: Locale): string {
  return MESSAGES[code][locale];
}

export class ApiError extends HttpException {
  constructor(
    public readonly code: ApiErrorCode,
    locale: Locale = 'de',
    /** Optional field-level hints. Must never contain user secrets. */
    public readonly details?: string[],
  ) {
    const status = STATUS[code];
    super(
      {
        error: {
          status,
          code,
          message: messageFor(code, locale),
          ...(details && details.length > 0 ? { details } : {}),
        },
      },
      status,
    );
  }
}
