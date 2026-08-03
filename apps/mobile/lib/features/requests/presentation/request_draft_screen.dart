// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_density.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/requests_controller.dart';
import '../data/attachment_picker.dart';
import '../domain/request_gateway.dart';
import '../domain/request_models.dart';
import '../domain/request_validation.dart';

/// Editor for one draft.
///
/// Validation runs on **submit**, not while typing: a half-written application
/// is exactly what a draft is for, and a form that turns red before the user
/// has finished a sentence is hostile. Saving therefore never validates.
class RequestDraftScreen extends ConsumerStatefulWidget {
  const RequestDraftScreen({
    required this.draftId,
    required this.kind,
    super.key,
  });

  /// `new` starts a fresh draft.
  final String draftId;

  /// Only used when starting a new draft.
  final RequestKind kind;

  @override
  ConsumerState<RequestDraftScreen> createState() => _RequestDraftScreenState();
}

class _RequestDraftScreenState extends ConsumerState<RequestDraftScreen> {
  late RequestDraft _draft;
  RequestValidation _validation = const RequestValidation(
    <RequestField, RequestFieldError>{},
  );
  bool _initialised = false;

  static const List<String> _financeCategories = <String>[
    'event',
    'material',
    'travel',
    'general',
  ];
  static const List<String> _feedbackCategories = <String>[
    'app',
    'campus',
    'general',
  ];

  /// Loads the draft once the store has actually been read.
  ///
  /// Reading before the provider resolves used to silently produce a *new*
  /// blank draft instead of the one the user tapped — the editor looked empty
  /// and a completed draft could not be submitted. So initialisation waits for
  /// data rather than assuming it is there.
  bool _ensureInitialised(AsyncValue<List<RequestDraft>> drafts) {
    if (_initialised) return true;
    if (!drafts.hasValue) return false;
    final RequestsController controller = ref.read(requestsProvider.notifier);
    _draft =
        controller.byId(widget.draftId) ??
        controller.create(widget.kind, now: DateTime.now());
    _initialised = true;
    return true;
  }

  String _categoryLabel(AppLocalizations l10n, String key) => switch (key) {
    'event' => l10n.requestsCategoryEvent,
    'material' => l10n.requestsCategoryMaterial,
    'travel' => l10n.requestsCategoryTravel,
    'app' => l10n.requestsCategoryApp,
    'campus' => l10n.requestsCategoryCampus,
    _ => l10n.requestsCategoryGeneral,
  };

  String? _errorText(AppLocalizations l10n, RequestField field) =>
      switch (_validation.errorFor(field)) {
        RequestFieldError.titleMissing => l10n.requestsErrorTitleMissing,
        RequestFieldError.titleTooLong => l10n.requestsErrorTitleTooLong,
        RequestFieldError.categoryMissing => l10n.requestsErrorCategoryMissing,
        RequestFieldError.amountMissing => l10n.requestsErrorAmountMissing,
        RequestFieldError.amountInvalid => l10n.requestsErrorAmountInvalid,
        RequestFieldError.amountZero => l10n.requestsErrorAmountZero,
        RequestFieldError.purposeMissing => l10n.requestsErrorPurposeMissing,
        RequestFieldError.descriptionMissing =>
          l10n.requestsErrorDescriptionMissing,
        RequestFieldError.descriptionTooLong =>
          l10n.requestsErrorDescriptionTooLong,
        RequestFieldError.contactEmailInvalid => l10n.requestsErrorEmailInvalid,
        null => null,
      };

  /// Human-readable size. Binary units, because that is what a file manager
  /// shows for the same file.
  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _addAttachments() async {
    final List<RequestAttachment> picked = await ref
        .read(attachmentPickerProvider)
        .pick();
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        attachments: <RequestAttachment>[..._draft.attachments, ...picked],
      );
    });
    // Persisted at once: the copy already exists on disk, and losing the
    // reference to it would leave an orphaned file behind.
    await _save(silent: true);
  }

  Future<void> _removeAttachment(RequestAttachment file) async {
    await ref.read(attachmentPickerProvider).discard(file);
    if (!mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        attachments: _draft.attachments
            .where((RequestAttachment a) => a.path != file.path)
            .toList(),
      );
    });
    await _save(silent: true);
  }

  Future<void> _save({bool silent = false}) async {
    await ref.read(requestsProvider.notifier).save(_draft, now: DateTime.now());
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.requestsSaved)));
  }

  Future<void> _submit() async {
    setState(() => _validation = RequestValidation.validate(_draft));
    if (!_validation.isValid) return;

    final SubmissionResult result = await ref
        .read(requestsProvider.notifier)
        .submit(_draft);
    if (!mounted) return;

    // The only outcome this build can produce is "nothing to submit to", and
    // it is reported as exactly that — never as a confirmation.
    final String message = switch (result) {
      SubmissionNotConnected() => context.l10n.requestsSubmitUnavailable,
      SubmissionFailed() => context.l10n.requestsSubmitUnavailable,
      SubmissionAccepted() => context.l10n.requestsSaved,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<RequestDraft>> drafts = ref.watch(requestsProvider);
    final AppLocalizations l10n = context.l10n;
    if (!_ensureInitialised(drafts)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.requestsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final AppMetrics metrics = context.metrics;
    final bool isFinance = _draft.kind.hasAmount;
    final List<String> categories = isFinance
        ? _financeCategories
        : _feedbackCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFinance ? l10n.requestsFinanceTitle : l10n.requestsFeedbackTitle,
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: l10n.requestsSave,
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(metrics.screenPadding),
        children: <Widget>[
          StatusBanner(
            tone: StatusTone.warning,
            icon: Icons.construction_outlined,
            title: l10n.requestsDevNoticeTitle,
            message: l10n.requestsDevNoticeBody,
          ),
          SizedBox(height: metrics.sectionGap),

          TextFormField(
            initialValue: _draft.title,
            decoration: InputDecoration(
              labelText: l10n.requestsFieldTitle,
              errorText: _errorText(l10n, RequestField.title),
            ),
            maxLength: RequestValidation.titleMaxLength,
            onChanged: (String value) => _draft = _draft.copyWith(title: value),
          ),
          const SizedBox(height: AppSpacing.md),

          DropdownButtonFormField<String>(
            // Without isExpanded the selected item keeps its intrinsic width
            // and pushes the field past the screen edge once text is scaled up.
            isExpanded: true,
            initialValue: _draft.category,
            decoration: InputDecoration(
              labelText: l10n.requestsFieldCategory,
              errorText: _errorText(l10n, RequestField.category),
            ),
            items: <DropdownMenuItem<String>>[
              for (final String key in categories)
                DropdownMenuItem<String>(
                  value: key,
                  child: Text(_categoryLabel(l10n, key)),
                ),
            ],
            onChanged: (String? value) =>
                setState(() => _draft = _draft.copyWith(category: value)),
          ),
          const SizedBox(height: AppSpacing.md),

          if (isFinance) ...<Widget>[
            TextFormField(
              initialValue: _draft.amount?.amount,
              decoration: InputDecoration(
                labelText: l10n.requestsFieldAmount,
                suffixText: '€',
                errorText: _errorText(l10n, RequestField.amount),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (String value) {
                // Parsed, never rounded: an unparseable value is kept as typed
                // so the user sees their own input in the error, not a guess.
                _draft = _draft.copyWith(
                  amount: Money.tryParse(value) ?? Money(amount: value.trim()),
                  clearAmount: value.trim().isEmpty,
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              initialValue: _draft.purpose,
              decoration: InputDecoration(
                labelText: l10n.requestsFieldPurpose,
                errorText: _errorText(l10n, RequestField.purpose),
              ),
              onChanged: (String value) =>
                  _draft = _draft.copyWith(purpose: value),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          TextFormField(
            initialValue: _draft.description,
            decoration: InputDecoration(
              labelText: l10n.requestsFieldDescription,
              errorText: _errorText(l10n, RequestField.description),
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 10,
            onChanged: (String value) =>
                _draft = _draft.copyWith(description: value),
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            initialValue: _draft.contactName,
            decoration: InputDecoration(
              labelText: l10n.requestsFieldContactName,
            ),
            onChanged: (String value) =>
                _draft = _draft.copyWith(contactName: value),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: _draft.contactEmail,
            decoration: InputDecoration(
              labelText: l10n.requestsFieldContactEmail,
              errorText: _errorText(l10n, RequestField.contactEmail),
            ),
            keyboardType: TextInputType.emailAddress,
            onChanged: (String value) =>
                _draft = _draft.copyWith(contactEmail: value),
          ),

          SizedBox(height: metrics.sectionGap),
          Text(
            l10n.requestsAttachments,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.requestsAttachmentsHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_draft.attachments.isEmpty)
            Text(
              l10n.requestsNoAttachments,
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final RequestAttachment file in _draft.attachments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file),
                title: Text(file.fileName),
                subtitle: file.sizeBytes == null
                    ? null
                    : Text(_formatSize(file.sizeBytes!)),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.requestsRemoveAttachment,
                  onPressed: () => _removeAttachment(file),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _addAttachments,
              icon: const Icon(Icons.attach_file),
              label: Text(l10n.requestsAddAttachment),
            ),
          ),

          SizedBox(height: metrics.sectionGap),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: AppSpacing.sm,
            overflowSpacing: AppSpacing.xs,
            overflowAlignment: OverflowBarAlignment.end,
            children: <Widget>[
              TextButton(onPressed: _save, child: Text(l10n.requestsSave)),
              FilledButton(
                onPressed: _submit,
                child: Text(l10n.requestsSubmit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
