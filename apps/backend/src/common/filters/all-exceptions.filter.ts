import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Request, Response } from 'express';
import { ApiError, messageFor } from '../errors/api-error';
import { DEFAULT_LOCALE, Locale, isSupportedLocale } from '../locale/locale';
import { asString } from '../util/coerce';

/**
 * Translates every escaping error into the documented public error shape.
 *
 * An unexpected exception is logged with a correlation id and answered with a
 * generic message. Internal details never reach the client, but the id makes
 * the log entry findable.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const requestId = randomUUID();

    // Best-effort locale so the error message matches the rest of the response.
    // asString rather than String(): `?locale[]=x` arrives as an array and
    // String() would turn it into text that could never match a locale.
    const rawLocale = asString(request.query?.['locale']).toLowerCase();
    const locale: Locale = isSupportedLocale(rawLocale) ? rawLocale : DEFAULT_LOCALE;

    if (exception instanceof ApiError) {
      const body = exception.getResponse() as { error: Record<string, unknown> };
      response.status(exception.getStatus()).json({
        error: { ...body.error, requestId },
      });
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const isNotFound = status === Number(HttpStatus.NOT_FOUND);
      const original = exception.getResponse();
      // Nest's built-in validation errors carry a useful `message` array.
      const details =
        typeof original === 'object' && original !== null && 'message' in original
          ? original.message
          : undefined;

      response.status(status).json({
        error: {
          status,
          code: isNotFound ? 'NOT_FOUND' : 'VALIDATION_FAILED',
          message: isNotFound
            ? messageFor('NEWS_ARTICLE_NOT_FOUND', locale)
            : messageFor('VALIDATION_FAILED', locale),
          ...(Array.isArray(details) ? { details } : {}),
          requestId,
        },
      });
      return;
    }

    this.logger.error(
      `Unhandled exception on ${request.method} ${request.path} (requestId=${requestId})`,
      exception instanceof Error ? exception.stack : String(exception),
    );

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      error: {
        status: HttpStatus.INTERNAL_SERVER_ERROR,
        code: 'INTERNAL_ERROR',
        message: messageFor('INTERNAL_ERROR', locale),
        requestId,
      },
    });
  }
}
