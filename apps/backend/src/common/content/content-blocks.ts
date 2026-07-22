/**
 * Sanitiser for Strapi "blocks" rich text — see docs/api.md §5.
 *
 * Two jobs, both defensive:
 *
 *  1. Reduce the payload to the block types the MVP client actually renders.
 *     A future Strapi block type must never be able to break a detail screen,
 *     so unknown types are dropped here and reported in `droppedBlockTypes`
 *     rather than forwarded and rendered blindly.
 *
 *  2. Strip everything that is not part of the public contract. Strapi
 *     internals (`documentId`, `attributes`, …) never reach the client, and
 *     link targets are restricted to schemes that are safe to hand to the
 *     operating system.
 */

const ALLOWED_LINK_SCHEMES = ['https:', 'mailto:', 'tel:'] as const;

const MIN_HEADING_LEVEL = 1;
const MAX_HEADING_LEVEL = 6;
const DEFAULT_HEADING_LEVEL = 2;

export interface TextNode {
  type: 'text';
  text: string;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  code?: boolean;
}

export interface LinkNode {
  type: 'link';
  url: string;
  children: TextNode[];
}

export type InlineNode = TextNode | LinkNode;

export interface ParagraphBlock {
  type: 'paragraph';
  children: InlineNode[];
}
export interface HeadingBlock {
  type: 'heading';
  level: number;
  children: InlineNode[];
}
export interface ListItemBlock {
  type: 'list-item';
  children: InlineNode[];
}
export interface ListBlock {
  type: 'list';
  format: 'ordered' | 'unordered';
  children: ListItemBlock[];
}
export interface QuoteBlock {
  type: 'quote';
  children: InlineNode[];
}
export interface ImageBlock {
  type: 'image';
  url: string;
  alternativeText: string | null;
  width: number | null;
  height: number | null;
}

export type ContentBlock =
  | ParagraphBlock
  | HeadingBlock
  | ListBlock
  | QuoteBlock
  | ImageBlock;

export interface SanitizedContent {
  blocks: ContentBlock[];
  /** Distinct block types that were removed, for observability and API metadata. */
  droppedBlockTypes: string[];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isSafeLinkUrl(url: unknown): url is string {
  if (typeof url !== 'string' || url.length === 0) {
    return false;
  }
  try {
    const parsed = new URL(url);
    return (ALLOWED_LINK_SCHEMES as readonly string[]).includes(parsed.protocol);
  } catch {
    return false;
  }
}

function isHttpsUrl(url: unknown): url is string {
  if (typeof url !== 'string' || url.length === 0) {
    return false;
  }
  try {
    return new URL(url).protocol === 'https:';
  } catch {
    return false;
  }
}

function sanitizeTextNode(node: Record<string, unknown>): TextNode | null {
  if (typeof node['text'] !== 'string') {
    return null;
  }
  const result: TextNode = { type: 'text', text: node['text'] };
  // Only copy marks that are explicitly true; `false` is noise on the wire.
  for (const mark of ['bold', 'italic', 'underline', 'strikethrough', 'code'] as const) {
    if (node[mark] === true) {
      result[mark] = true;
    }
  }
  return result;
}

/**
 * Inline children. An unsafe link degrades to its plain text rather than
 * vanishing, so the reader never silently loses wording.
 */
function sanitizeInline(children: unknown): InlineNode[] {
  if (!Array.isArray(children)) {
    return [];
  }

  const result: InlineNode[] = [];
  for (const child of children) {
    if (!isRecord(child)) {
      continue;
    }

    if (child['type'] === 'link') {
      const linkText = sanitizeInline(child['children']).filter(
        (node): node is TextNode => node.type === 'text',
      );
      if (isSafeLinkUrl(child['url'])) {
        result.push({ type: 'link', url: child['url'], children: linkText });
      } else {
        result.push(...linkText);
      }
      continue;
    }

    const text = sanitizeTextNode(child);
    if (text) {
      result.push(text);
    }
  }
  return result;
}

function clampHeadingLevel(level: unknown): number {
  if (typeof level !== 'number' || !Number.isFinite(level)) {
    return DEFAULT_HEADING_LEVEL;
  }
  return Math.min(MAX_HEADING_LEVEL, Math.max(MIN_HEADING_LEVEL, Math.trunc(level)));
}

function sanitizeImage(block: Record<string, unknown>): ImageBlock | null {
  // Strapi nests the file under `image`; tolerate a flattened shape too.
  const image = isRecord(block['image']) ? block['image'] : block;
  const url = image['url'];
  if (!isHttpsUrl(url)) {
    return null;
  }
  return {
    type: 'image',
    url,
    alternativeText:
      typeof image['alternativeText'] === 'string' ? image['alternativeText'] : null,
    width: typeof image['width'] === 'number' ? image['width'] : null,
    height: typeof image['height'] === 'number' ? image['height'] : null,
  };
}

export function sanitizeBlocks(input: unknown): SanitizedContent {
  if (!Array.isArray(input)) {
    return { blocks: [], droppedBlockTypes: [] };
  }

  const blocks: ContentBlock[] = [];
  const dropped = new Set<string>();

  for (const raw of input) {
    if (!isRecord(raw) || typeof raw['type'] !== 'string') {
      dropped.add('unknown');
      continue;
    }

    const type = raw['type'];

    switch (type) {
      case 'paragraph':
        blocks.push({ type: 'paragraph', children: sanitizeInline(raw['children']) });
        break;

      case 'heading':
        blocks.push({
          type: 'heading',
          level: clampHeadingLevel(raw['level']),
          children: sanitizeInline(raw['children']),
        });
        break;

      case 'quote':
        blocks.push({ type: 'quote', children: sanitizeInline(raw['children']) });
        break;

      case 'list': {
        const items = Array.isArray(raw['children']) ? raw['children'] : [];
        blocks.push({
          type: 'list',
          format: raw['format'] === 'ordered' ? 'ordered' : 'unordered',
          children: items
            .filter(isRecord)
            .filter((item) => item['type'] === 'list-item')
            .map((item) => ({
              type: 'list-item' as const,
              children: sanitizeInline(item['children']),
            })),
        });
        break;
      }

      case 'image': {
        const image = sanitizeImage(raw);
        if (image) {
          blocks.push(image);
        } else {
          // A broken or non-https image is dropped, not rendered as a hole.
          dropped.add('image');
        }
        break;
      }

      default:
        dropped.add(type);
        break;
    }
  }

  return { blocks, droppedBlockTypes: [...dropped] };
}
