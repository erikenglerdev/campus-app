// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import '../../../core/content/content_block.dart';
import '../../../core/links/safe_link_launcher.dart';
import '../../../core/network/json.dart';

/// A news channel as delivered by `GET /v1/news/channels`.
///
/// The client never hard-codes a channel list; every channel originates here.
class NewsChannel {
  const NewsChannel({
    required this.slug,
    required this.name,
    required this.sortOrder,
    required this.defaultSubscribed,
    this.description,
    this.iconKey,
    this.colorHex,
  });

  final String slug;
  final String name;
  final String? description;
  final String? iconKey;

  /// Editorial colour hint. Never used as the sole carrier of a state and
  /// never used as a text colour, because its contrast is not guaranteed.
  final String? colorHex;

  final int sortOrder;

  /// Evaluated exactly once per slug, on the channel's first ever appearance.
  final bool defaultSubscribed;

  static NewsChannel? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? slug = asString(map['slug']);
    if (slug == null) return null;
    return NewsChannel(
      slug: slug,
      name: asString(map['name']) ?? slug,
      description: asString(map['description']),
      iconKey: asString(map['iconKey']),
      colorHex: asString(map['colorHex']),
      sortOrder: asInt(map['sortOrder']) ?? 0,
      defaultSubscribed: asBool(map['defaultSubscribed']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'slug': slug,
    'name': name,
    'description': description,
    'iconKey': iconKey,
    'colorHex': colorHex,
    'sortOrder': sortOrder,
    'defaultSubscribed': defaultSubscribed,
  };

  static List<NewsChannel> listFromJson(Object? json) =>
      asList(json).map(NewsChannel.fromJson).whereType<NewsChannel>().toList()
        ..sort((NewsChannel a, NewsChannel b) {
          final int order = a.sortOrder.compareTo(b.sortOrder);
          return order != 0 ? order : a.name.compareTo(b.name);
        });
}

/// Lightweight channel reference embedded in an article.
class NewsChannelRef {
  const NewsChannelRef({required this.slug, required this.name, this.colorHex});

  final String slug;
  final String name;
  final String? colorHex;

  static NewsChannelRef? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? slug = asString(map['slug']);
    if (slug == null) return null;
    return NewsChannelRef(
      slug: slug,
      name: asString(map['name']) ?? slug,
      colorHex: asString(map['colorHex']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'slug': slug,
    'name': name,
    'colorHex': colorHex,
  };
}

/// An author credit. `role` is optional and hidden when absent.
class NewsAuthor {
  const NewsAuthor({required this.name, this.role});

  final String name;
  final String? role;

  static NewsAuthor? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? name = asString(map['name']);
    if (name == null) return null;
    return NewsAuthor(name: name, role: asString(map['role']));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'role': role,
  };
}

/// An editorial image. `null` when no approved image exists.
class NewsImage {
  const NewsImage({
    required this.url,
    this.alternativeText,
    this.width,
    this.height,
  });

  final String url;
  final String? alternativeText;
  final int? width;
  final int? height;

  double? get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : null;

  static NewsImage? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? url = asString(map['url']);
    if (url == null || !SafeLinkLauncher.isAllowed(url)) return null;
    return NewsImage(
      url: url,
      alternativeText: asString(map['alternativeText']),
      width: asInt(map['width']),
      height: asInt(map['height']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'alternativeText': alternativeText,
    'width': width,
    'height': height,
  };
}

/// A news article. List entries carry an empty [content].
class NewsArticle {
  const NewsArticle({
    required this.slug,
    required this.title,
    required this.isPinned,
    this.teaser,
    this.publishedAt,
    this.heroImage,
    this.channels = const <NewsChannelRef>[],
    this.authors = const <NewsAuthor>[],
    this.sourceName,
    this.sourceUrl,
    this.content = const <ContentBlock>[],
  });

  final String slug;
  final String title;
  final String? teaser;
  final DateTime? publishedAt;
  final bool isPinned;
  final NewsImage? heroImage;
  final List<NewsChannelRef> channels;
  final List<NewsAuthor> authors;
  final String? sourceName;

  /// Always a validated `https` URL or `null`.
  final String? sourceUrl;

  final List<ContentBlock> content;

  /// The raw JSON this article was parsed from, used for caching.
  static NewsArticle? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? slug = asString(map['slug']);
    final String? title = asString(map['title']);
    if (slug == null || title == null) return null;
    final String? sourceUrl = asString(map['sourceUrl']);
    return NewsArticle(
      slug: slug,
      title: title,
      teaser: asString(map['teaser']),
      publishedAt: asDateTime(map['publishedAt']),
      isPinned: asBool(map['isPinned']) ?? false,
      heroImage: NewsImage.fromJson(map['heroImage']),
      channels: asList(map['channels'])
          .map(NewsChannelRef.fromJson)
          .whereType<NewsChannelRef>()
          .toList(growable: false),
      authors: asList(map['authors'])
          .map(NewsAuthor.fromJson)
          .whereType<NewsAuthor>()
          .toList(growable: false),
      sourceName: asString(map['sourceName']),
      sourceUrl: SafeLinkLauncher.isAllowed(sourceUrl) ? sourceUrl : null,
      content: ContentBlock.parse(map['content']),
    );
  }

  static List<NewsArticle> listFromJson(Object? json) => asList(json)
      .map(NewsArticle.fromJson)
      .whereType<NewsArticle>()
      .toList(growable: false);
}

/// One page of the news list plus the pagination metadata.
class NewsPage {
  const NewsPage({
    required this.articles,
    required this.page,
    required this.totalPages,
  });

  final List<NewsArticle> articles;
  final int page;
  final int totalPages;

  bool get hasNextPage => page < totalPages;
}
