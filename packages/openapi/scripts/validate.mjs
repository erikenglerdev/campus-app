#!/usr/bin/env node
/**
 * Structural check of the published OpenAPI contract.
 *
 * This is intentionally dependency-free. It does not try to be a full OpenAPI
 * validator — it asserts the guarantees this project actually makes, so a
 * regression in the contract fails CI rather than reaching a client.
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const documentPath = join(here, '..', 'openapi.json');

/** Endpoints the mobile client depends on. */
const REQUIRED_PATHS = [
  '/health/live',
  '/health/ready',
  '/v1/news/channels',
  '/v1/news',
  '/v1/news/{slug}',
  '/v1/contact-areas',
  '/v1/contact-areas/{slug}',
  '/v1/canteens',
  '/v1/canteens/{slug}/menu',
  '/v1/rooms',
  '/v1/rooms/{roomKey}',
];

/**
 * Strapi internals that must never appear anywhere in the contract.
 * `attributes` is excluded from this list on purpose: it is a legitimate word
 * in prose, so it is checked structurally instead (see below).
 */
const FORBIDDEN_TOKENS = ['documentId', 'populate', 'localizations', 'image_url', 'location_id'];

const problems = [];

let document;
try {
  document = JSON.parse(readFileSync(documentPath, 'utf8'));
} catch (error) {
  console.error(
    `Cannot read ${documentPath}. Run "pnpm openapi:generate" first.\n${error.message}`,
  );
  process.exit(1);
}

if (document.info?.license?.name !== 'AGPL-3.0-only') {
  problems.push(`info.license.name must be "AGPL-3.0-only", got "${document.info?.license?.name}"`);
}

for (const path of REQUIRED_PATHS) {
  if (!document.paths?.[path]) {
    problems.push(`missing required path: ${path}`);
  }
}

// The API is read-only; any mutating verb would be a contract change.
for (const [path, operations] of Object.entries(document.paths ?? {})) {
  for (const method of Object.keys(operations)) {
    if (!['get', 'parameters'].includes(method)) {
      problems.push(`unexpected non-GET operation: ${method.toUpperCase()} ${path}`);
    }
  }
}

/**
 * Leak check.
 *
 * Deliberately structural rather than a substring sweep over the whole
 * document: descriptions legitimately mention these names to state that they
 * are NOT exposed (e.g. "the upstream location_id is never exposed"). Only
 * actual identifiers — schema properties, parameter names and path segments —
 * would constitute a real leak.
 */
function checkIdentifier(identifier, where) {
  for (const token of FORBIDDEN_TOKENS) {
    if (identifier === token || identifier.toLowerCase() === token.toLowerCase()) {
      problems.push(`contract leaks an internal identifier "${token}" as ${where}`);
    }
  }
}

for (const [name, schema] of Object.entries(document.components?.schemas ?? {})) {
  const properties = Object.keys(schema.properties ?? {});
  for (const property of properties) {
    checkIdentifier(property, `a property of schema "${name}"`);
  }
  // A raw Strapi envelope would carry both of these together.
  if (properties.includes('attributes') && properties.includes('data')) {
    problems.push(`schema "${name}" looks like a raw Strapi envelope (data + attributes)`);
  }
}

for (const [path, operations] of Object.entries(document.paths ?? {})) {
  for (const segment of path.split('/')) {
    checkIdentifier(segment.replace(/[{}]/g, ''), `a path segment of ${path}`);
  }
  for (const operation of Object.values(operations)) {
    for (const parameter of operation.parameters ?? []) {
      checkIdentifier(parameter.name ?? '', `a query/path parameter of ${path}`);
    }
  }
}

if (problems.length > 0) {
  console.error('OpenAPI contract validation FAILED:');
  for (const problem of problems) {
    console.error(`  - ${problem}`);
  }
  process.exit(1);
}

console.log(
  `OpenAPI contract OK: ${Object.keys(document.paths).length} paths, read-only, no upstream identifiers leaked.`,
);
