// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import 'application_files.dart';
import 'idempotency_key.dart';

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
/// Only a reference — the bytes live in the app's documents directory, where
/// the picker copied them, and are read once at the moment of submission.
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
/// Drafts are user-authored data rather than a cache, so nothing here is ever
/// discarded to make room. They stay on the device until the user submits one.
@immutable
class RequestDraft {
  const RequestDraft({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    required this.idempotencyKey,
    this.title = '',
    this.category,
    this.amount,
    this.purpose = '',
    this.description = '',
    this.applicant = '',
    this.locationId,
    this.contactName,
    this.contactEmail,
    this.files = const <ApplicationFileSlot, RequestAttachment>{},
  });

  final String id;
  final RequestKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Generated once, when the draft is created, and kept for its whole life.
  ///
  /// This is what makes a retry safe: resending the same draft after a timeout
  /// carries the same key, so the receiving system replays its original answer
  /// instead of filing a second application. Generating it at send time would
  /// break exactly the case it exists for.
  final String idempotencyKey;

  final String title;
  final String? category;

  /// Only meaningful for [RequestKind.financeApplication].
  final Money? amount;

  /// What the money is for. Finance applications only.
  final String purpose;

  final String description;

  /// Name of the person applying. Sent as `applicant`.
  final String applicant;

  /// Which board the application is addressed to. Comes from the endpoint's
  /// own list; never invented here.
  final int? locationId;

  /// Optional — a submission may be anonymous.
  final String? contactName;
  final String? contactEmail;

  /// The picked file per multipart slot.
  final Map<ApplicationFileSlot, RequestAttachment> files;

  RequestAttachment? fileFor(ApplicationFileSlot slot) => files[slot];

  /// Whether this draft has anything in it worth keeping.
  bool get isEmpty =>
      title.trim().isEmpty &&
      description.trim().isEmpty &&
      purpose.trim().isEmpty &&
      applicant.trim().isEmpty &&
      amount == null &&
      locationId == null &&
      files.isEmpty;

  RequestDraft copyWith({
    String? title,
    String? category,
    bool clearCategory = false,
    Money? amount,
    bool clearAmount = false,
    String? purpose,
    String? description,
    String? applicant,
    int? locationId,
    bool clearLocation = false,
    String? contactName,
    String? contactEmail,
    Map<ApplicationFileSlot, RequestAttachment>? files,
    DateTime? updatedAt,
  }) => RequestDraft(
    id: id,
    kind: kind,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    // Never replaced: a new key would turn a retry into a second application.
    idempotencyKey: idempotencyKey,
    title: title ?? this.title,
    category: clearCategory ? null : (category ?? this.category),
    amount: clearAmount ? null : (amount ?? this.amount),
    purpose: purpose ?? this.purpose,
    description: description ?? this.description,
    applicant: applicant ?? this.applicant,
    locationId: clearLocation ? null : (locationId ?? this.locationId),
    contactName: contactName ?? this.contactName,
    contactEmail: contactEmail ?? this.contactEmail,
    files: files ?? this.files,
  );

  /// Replaces or clears one slot.
  RequestDraft withFile(ApplicationFileSlot slot, RequestAttachment? file) {
    final Map<ApplicationFileSlot, RequestAttachment> next =
        Map<ApplicationFileSlot, RequestAttachment>.of(files);
    if (file == null) {
      next.remove(slot);
    } else {
      next[slot] = file;
    }
    return copyWith(files: next);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.storageValue,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'idempotencyKey': idempotencyKey,
    'title': title,
    if (category != null) 'category': category,
    if (amount != null) 'amount': amount!.amount,
    if (amount != null) 'currency': amount!.currency,
    'purpose': purpose,
    'description': description,
    'applicant': applicant,
    if (locationId != null) 'locationId': locationId,
    if (contactName != null) 'contactName': contactName,
    if (contactEmail != null) 'contactEmail': contactEmail,
    'files': <String, dynamic>{
      for (final MapEntry<ApplicationFileSlot, RequestAttachment> entry
          in files.entries)
        entry.key.field: entry.value.toJson(),
    },
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
    final Object? storedKey = json['idempotencyKey'];
    final Map<ApplicationFileSlot, RequestAttachment> files =
        <ApplicationFileSlot, RequestAttachment>{};
    if (json['files'] is Map) {
      (json['files'] as Map<Object?, Object?>).forEach((Object? k, Object? v) {
        final ApplicationFileSlot? slot = ApplicationFileSlot.fromStorage(
          k is String ? k : null,
        );
        final RequestAttachment? file = RequestAttachment.fromJson(v);
        if (slot != null && file != null) files[slot] = file;
      });
    }
    return RequestDraft(
      id: id,
      kind: kind,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      // A draft stored before keys existed, or with a hand-edited one, gets a
      // fresh valid key rather than failing to load. It has demonstrably never
      // been submitted, so there is nothing for it to replay.
      idempotencyKey:
          IdempotencyKey.isValid(storedKey is String ? storedKey : null)
          ? storedKey! as String
          : IdempotencyKey.generate(),
      applicant: json['applicant'] is String ? json['applicant'] as String : '',
      locationId: json['locationId'] is int ? json['locationId'] as int : null,
      files: files,
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

/// A case that has been submitted, as the receiving system described it.
///
/// **[trackingUrl] is a secret.** It is the only way anyone reaches this
/// application, it authenticates nobody, and possessing it is possessing the
/// case. It is stored locally, shown to the user, and never logged, never
/// reported, never attached to diagnostics.
@immutable
class SubmittedRequest {
  const SubmittedRequest({
    required this.id,
    required this.kind,
    required this.title,
    required this.submittedAt,
    required this.status,
    this.number,
    this.trackingUrl,
    this.receiptPdfUrl,
    this.wasReplay = false,
  });

  final String id;
  final RequestKind kind;
  final String title;
  final DateTime submittedAt;
  final RequestStatus status;

  /// Assigned by the receiving board, or `null` where numbering is off.
  final String? number;

  /// The secret status link.
  ///
  /// Opened through the app's safe launcher, which only accepts `https` — a
  /// link that arrives from a server is untrusted input, and handing an
  /// arbitrary scheme to the operating system is how those become an attack.
  final String? trackingUrl;

  /// Receipt as PDF. Carries the same token, so it is equally secret.
  final String? receiptPdfUrl;

  /// True when the endpoint replayed an earlier submission because the same
  /// key was sent again. Nothing was filed twice — worth saying so plainly.
  final bool wasReplay;

  static bool _isSafe(String? url) {
    if (url == null) return false;
    final Uri? parsed = Uri.tryParse(url);
    return parsed != null && parsed.scheme == 'https' && parsed.host.isNotEmpty;
  }

  bool get hasSafeTrackingUrl => _isSafe(trackingUrl);

  bool get hasSafeReceiptUrl => _isSafe(receiptPdfUrl);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.storageValue,
    'title': title,
    'submittedAt': submittedAt.toIso8601String(),
    'status': status.storageValue,
    if (number != null) 'number': number,
    if (trackingUrl != null) 'trackingUrl': trackingUrl,
    if (receiptPdfUrl != null) 'receiptPdfUrl': receiptPdfUrl,
  };

  static SubmittedRequest? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? id = json['id'];
    final RequestKind? kind = RequestKind.fromStorage(
      json['kind'] is String ? json['kind'] as String : null,
    );
    if (id is! String || kind == null) return null;
    return SubmittedRequest(
      id: id,
      kind: kind,
      title: json['title'] is String ? json['title'] as String : '',
      submittedAt:
          DateTime.tryParse(
            json['submittedAt'] is String ? json['submittedAt'] as String : '',
          ) ??
          DateTime(2026),
      status:
          RequestStatus.fromStorage(
            json['status'] is String ? json['status'] as String : null,
          ) ??
          RequestStatus.submitted,
      number: json['number'] is String ? json['number'] as String : null,
      trackingUrl: json['trackingUrl'] is String
          ? json['trackingUrl'] as String
          : null,
      receiptPdfUrl: json['receiptPdfUrl'] is String
          ? json['receiptPdfUrl'] as String
          : null,
    );
  }

  /// Deliberately does **not** include the links: this is what ends up in log
  /// lines and error reports.
  @override
  String toString() => 'SubmittedRequest($id, number: $number)';
}
