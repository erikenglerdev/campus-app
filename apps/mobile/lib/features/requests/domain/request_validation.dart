// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'application_files.dart';
import 'request_models.dart';

/// Which field failed, and why.
///
/// A typed enum rather than a message: the reason belongs to the domain, the
/// wording belongs to `gen_l10n`. That also keeps validation testable without
/// pulling a BuildContext into it.
enum RequestFieldError {
  titleMissing,
  titleTooLong,
  categoryMissing,
  amountMissing,
  amountInvalid,
  amountZero,
  purposeMissing,
  descriptionMissing,
  descriptionTooLong,
  contactEmailInvalid,
  locationMissing,
  applicantMissing,
  requiredFileMissing,
}

/// Which field an error belongs to.
enum RequestField {
  title,
  category,
  amount,
  purpose,
  description,
  contactEmail,
  location,
  applicant,
  files,
}

/// The result of validating a draft.
class RequestValidation {
  const RequestValidation(this.errors);

  final Map<RequestField, RequestFieldError> errors;

  bool get isValid => errors.isEmpty;

  RequestFieldError? errorFor(RequestField field) => errors[field];

  static const int titleMaxLength = 120;
  static const int descriptionMaxLength = 4000;

  /// Validates a draft for **submission**.
  ///
  /// Saving a draft deliberately does not go through this: a half-written
  /// application is exactly what a draft is for. Only the attempt to submit
  /// has to be complete.
  static RequestValidation validate(RequestDraft draft) {
    final Map<RequestField, RequestFieldError> errors =
        <RequestField, RequestFieldError>{};

    final String title = draft.title.trim();
    if (title.isEmpty) {
      errors[RequestField.title] = RequestFieldError.titleMissing;
    } else if (title.length > titleMaxLength) {
      errors[RequestField.title] = RequestFieldError.titleTooLong;
    }

    if ((draft.category ?? '').trim().isEmpty) {
      errors[RequestField.category] = RequestFieldError.categoryMissing;
    }

    final String description = draft.description.trim();
    if (description.isEmpty) {
      errors[RequestField.description] = RequestFieldError.descriptionMissing;
    } else if (description.length > descriptionMaxLength) {
      errors[RequestField.description] = RequestFieldError.descriptionTooLong;
    }

    if (draft.kind.hasAmount) {
      final Money? amount = draft.amount;
      if (amount == null) {
        errors[RequestField.amount] = RequestFieldError.amountMissing;
      } else if (Money.tryParse(amount.amount) == null) {
        errors[RequestField.amount] = RequestFieldError.amountInvalid;
      } else if (amount.isZero) {
        // A €0 application is not a rounding problem, it is a mistake.
        errors[RequestField.amount] = RequestFieldError.amountZero;
      }

      if (draft.purpose.trim().isEmpty) {
        errors[RequestField.purpose] = RequestFieldError.purposeMissing;
      }

      // What the endpoint itself requires. Checked here so the form can point
      // at the field, rather than surfacing a server message with no anchor.
      if (draft.locationId == null) {
        errors[RequestField.location] = RequestFieldError.locationMissing;
      }
      if (draft.applicant.trim().isEmpty) {
        errors[RequestField.applicant] = RequestFieldError.applicantMissing;
      }
      final bool missingFile = ApplicationFileSlot.required.any(
        (ApplicationFileSlot slot) => draft.fileFor(slot) == null,
      );
      if (missingFile) {
        errors[RequestField.files] = RequestFieldError.requiredFileMissing;
      }
    }

    final String? email = draft.contactEmail?.trim();
    // Contact details are optional; only a *given* address has to look like one.
    if (email != null && email.isNotEmpty && !_looksLikeEmail(email)) {
      errors[RequestField.contactEmail] = RequestFieldError.contactEmailInvalid;
    }

    return RequestValidation(errors);
  }

  /// Deliberately permissive: the goal is to catch a typo, not to re-implement
  /// RFC 5322 and reject an address that is in fact valid.
  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(value);
}
