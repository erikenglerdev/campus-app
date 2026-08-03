// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

/// The two kinds of submission this area handles.
enum RequestKind {
  /// A request for money from the student body's budget.
  financeApplication('finance-application'),

  /// Feedback about the app, the campus or the student body's work.
  feedback('feedback');

  const RequestKind(this.storageValue);

  /// Stable identifier written to local storage, never the enum index.
  final String storageValue;

  static RequestKind? fromStorage(String? value) {
    for (final RequestKind kind in RequestKind.values) {
      if (kind.storageValue == value) return kind;
    }
    return null;
  }

  /// Whether this kind carries an amount of money.
  bool get hasAmount => this == RequestKind.financeApplication;
}

/// An amount of money, kept as an exact decimal **string**.
///
/// Never a `double`: `0.1 + 0.2` is not `0.3` in binary floating point, and an
/// application for €4.30 that is stored as €4.2999999 is a defect with legal
/// consequences. The app parses, validates and formats the decimal text and
/// hands the same text to whatever backend eventually receives it — exactly
/// how meal prices already travel through this code base.
@immutable
class Money {
  const Money({required this.amount, this.currency = 'EUR'});

  /// Decimal representation, e.g. `"120.50"`. Always uses a full stop.
  final String amount;

  /// ISO 4217 code.
  final String currency;

  /// Parses user input in either notation.
  ///
  /// Returns `null` for anything that is not a non-negative amount with at
  /// most two decimal places — a rejected value is never silently rounded
  /// into something the user did not type.
  static Money? tryParse(String input, {String currency = 'EUR'}) {
    final String trimmed = input.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(trimmed)) return null;
    return Money(amount: trimmed, currency: currency);
  }

  /// The amount in minor units (cents), for comparisons only.
  int get minorUnits {
    final List<String> parts = amount.split('.');
    final int major = int.tryParse(parts.first) ?? 0;
    final String fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
    return major * 100 + (int.tryParse(fraction) ?? 0);
  }

  bool get isZero => minorUnits == 0;

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => '$amount $currency';
}

/// A file the user picked to send along.
///
/// Only a reference: the bytes stay where they are until there is something to
/// send them to. Nothing is uploaded anywhere in this version.
@immutable
class RequestAttachment {
  const RequestAttachment({
    required this.fileName,
    required this.path,
    this.sizeBytes,
  });

  final String fileName;
  final String path;
  final int? sizeBytes;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fileName': fileName,
    'path': path,
    if (sizeBytes != null) 'sizeBytes': sizeBytes,
  };

  static RequestAttachment? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? name = json['fileName'];
    final Object? path = json['path'];
    if (name is! String || path is! String) return null;
    return RequestAttachment(
      fileName: name,
      path: path,
      sizeBytes: json['sizeBytes'] is int ? json['sizeBytes'] as int : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RequestAttachment &&
      other.fileName == fileName &&
      other.path == path;

  @override
  int get hashCode => Object.hash(fileName, path);
}

/// A locally stored, editable draft.
///
/// Drafts never leave the device in this version. They are user-authored data
/// rather than a cache, so nothing here is ever discarded to make room.
@immutable
class RequestDraft {
  const RequestDraft({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.category,
    this.amount,
    this.purpose = '',
    this.description = '',
    this.contactName,
    this.contactEmail,
    this.attachments = const <RequestAttachment>[],
  });

  final String id;
  final RequestKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String title;
  final String? category;

  /// Only meaningful for [RequestKind.financeApplication].
  final Money? amount;

  /// What the money is for. Finance applications only.
  final String purpose;

  final String description;

  /// Optional — a submission may be anonymous.
  final String? contactName;
  final String? contactEmail;

  final List<RequestAttachment> attachments;

  /// Whether this draft has anything in it worth keeping.
  bool get isEmpty =>
      title.trim().isEmpty &&
      description.trim().isEmpty &&
      purpose.trim().isEmpty &&
      amount == null &&
      attachments.isEmpty;

  RequestDraft copyWith({
    String? title,
    String? category,
    bool clearCategory = false,
    Money? amount,
    bool clearAmount = false,
    String? purpose,
    String? description,
    String? contactName,
    String? contactEmail,
    List<RequestAttachment>? attachments,
    DateTime? updatedAt,
  }) => RequestDraft(
    id: id,
    kind: kind,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    title: title ?? this.title,
    category: clearCategory ? null : (category ?? this.category),
    amount: clearAmount ? null : (amount ?? this.amount),
    purpose: purpose ?? this.purpose,
    description: description ?? this.description,
    contactName: contactName ?? this.contactName,
    contactEmail: contactEmail ?? this.contactEmail,
    attachments: attachments ?? this.attachments,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.storageValue,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'title': title,
    if (category != null) 'category': category,
    if (amount != null) 'amount': amount!.amount,
    if (amount != null) 'currency': amount!.currency,
    'purpose': purpose,
    'description': description,
    if (contactName != null) 'contactName': contactName,
    if (contactEmail != null) 'contactEmail': contactEmail,
    'attachments': attachments
        .map((RequestAttachment a) => a.toJson())
        .toList(),
  };

  static RequestDraft? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? id = json['id'];
    final RequestKind? kind = RequestKind.fromStorage(
      json['kind'] is String ? json['kind'] as String : null,
    );
    if (id is! String || kind == null) return null;
    DateTime parseDate(Object? value) =>
        DateTime.tryParse(value is String ? value : '') ?? DateTime(2026);
    final Object? rawAmount = json['amount'];
    return RequestDraft(
      id: id,
      kind: kind,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      title: json['title'] is String ? json['title'] as String : '',
      category: json['category'] is String ? json['category'] as String : null,
      amount: rawAmount is String
          ? Money(
              amount: rawAmount,
              currency: json['currency'] is String
                  ? json['currency'] as String
                  : 'EUR',
            )
          : null,
      purpose: json['purpose'] is String ? json['purpose'] as String : '',
      description: json['description'] is String
          ? json['description'] as String
          : '',
      contactName: json['contactName'] is String
          ? json['contactName'] as String
          : null,
      contactEmail: json['contactEmail'] is String
          ? json['contactEmail'] as String
          : null,
      attachments:
          (json['attachments'] is List
                  ? (json['attachments'] as List<Object?>)
                  : const <Object?>[])
              .map(RequestAttachment.fromJson)
              .whereType<RequestAttachment>()
              .toList(),
    );
  }
}

/// What happened to a submission after it left the device.
///
/// Prepared for the API that does not exist yet, so the storage format does
/// not have to change when it arrives.
enum RequestStatus {
  submitted('submitted'),
  inReview('in-review'),
  accepted('accepted'),
  rejected('rejected'),
  withdrawn('withdrawn');

  const RequestStatus(this.storageValue);

  final String storageValue;

  static RequestStatus? fromStorage(String? value) {
    for (final RequestStatus status in RequestStatus.values) {
      if (status.storageValue == value) return status;
    }
    return null;
  }
}

/// A case that has been submitted.
///
/// Nothing produces one of these yet — there is no endpoint. The type exists
/// so the local store, the list and the link handling are already shaped for
/// the real thing instead of being retrofitted later.
@immutable
class SubmittedRequest {
  const SubmittedRequest({
    required this.id,
    required this.kind,
    required this.title,
    required this.submittedAt,
    required this.status,
    this.trackingUrl,
  });

  final String id;
  final RequestKind kind;
  final String title;
  final DateTime submittedAt;
  final RequestStatus status;

  /// A link the backend may return.
  ///
  /// Opened through the app's safe launcher, which only accepts `https` — a
  /// link that arrives from a server is untrusted input, and handing an
  /// arbitrary scheme to the operating system is how those become an attack.
  final String? trackingUrl;

  bool get hasSafeTrackingUrl {
    final String? url = trackingUrl;
    if (url == null) return false;
    final Uri? parsed = Uri.tryParse(url);
    return parsed != null && parsed.scheme == 'https' && parsed.host.isNotEmpty;
  }
}
