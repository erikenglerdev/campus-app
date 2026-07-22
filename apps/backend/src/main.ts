import { VersioningType } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { JsonLogger } from './common/logger/json-logger.service';
import { ENV } from './config/app-config.module';
import { Env } from './config/env.schema';
import { buildOpenApiConfig } from './openapi';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { logger: new JsonLogger() });

  const env = app.get<Env>(ENV);

  // Content endpoints are versioned in the URI (/v1/...). Health and docs stay
  // unversioned so probes never break on a version bump.
  app.enableVersioning({ type: VersioningType.URI, prefix: 'v' });

  app.enableCors({
    // A wildcard is rejected at config validation time when NODE_ENV=production.
    origin: env.CORS_ALLOWED_ORIGINS.includes('*') ? true : env.CORS_ALLOWED_ORIGINS,
    methods: ['GET', 'OPTIONS'],
    credentials: false,
    maxAge: 3600,
  });

  app.useGlobalFilters(new AllExceptionsFilter());
  app.enableShutdownHooks();

  const document = SwaggerModule.createDocument(app, buildOpenApiConfig(new DocumentBuilder()));
  SwaggerModule.setup('docs', app, document, { jsonDocumentUrl: 'docs-json' });

  await app.listen(env.PORT, env.HOST);
}

void bootstrap();
