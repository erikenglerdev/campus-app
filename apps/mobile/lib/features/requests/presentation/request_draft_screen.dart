// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/requests_controller.dart';
import '../data/attachment_picker.dart';
import '../domain/application_files.dart';
import '../domain/application_location.dart';
import '../domain/request_gateway.dart';
import '../domain/request_models.dart';
import '../domain/request_validation.dart';
import 'submission_result_screen.dart';

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
  bool _submitting = false;

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
        RequestFieldError.locationMissing => l10n.requestsErrorLocationMissing,
        RequestFieldError.applicantMissing =>
          l10n.requestsErrorApplicantMissing,
        RequestFieldError.requiredFileMissing => l10n.requestsSubmitIncomplete,
        null => null,
      };

  static String slotLabel(AppLocalizations l10n, ApplicationFileSlot slot) =>
      switch (slot) {
        ApplicationFileSlot.financeRequest => l10n.requestsSlotFinanceRequest,
        ApplicationFileSlot.studentCard => l10n.requestsSlotStudentCard,
        ApplicationFileSlot.annexA => l10n.requestsSlotAnnexA,
        ApplicationFileSlot.annexB => l10n.requestsSlotAnnexB,
      };

  /// Human-readable size. Binary units, because that is what a file manager
  /// shows for the same file.
  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Picks a file for one named slot.
  ///
  /// The picked file is checked against the slot before it is kept: a PNG in
  /// the finance-request field is a guaranteed 400, and saying so here costs
  /// the user a tap instead of a failed submission.
  Future<void> _pickInto(ApplicationFileSlot slot) async {
    final List<RequestAttachment> picked = await ref
        .read(attachmentPickerProvider)
        .pick();
    if (picked.isEmpty || !mounted) return;
    final RequestAttachment file = picked.first;
    final AppLocalizations l10n = context.l10n;

    String? problem;
    if (!slot.accepts(file.fileName)) {
      problem = l10n.requestsSlotWrongType;
    } else if (!slot.acceptsSize(file.sizeBytes ?? 0)) {
      problem = l10n.requestsSlotTooLarge;
    }
    if (problem != null) {
      // Nothing is kept, so the copy the picker made is discarded again.
      for (final RequestAttachment rejected in picked) {
        await ref.read(attachmentPickerProvider).discard(rejected);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }

    final RequestAttachment? replaced = _draft.fileFor(slot);
    setState(() => _draft = _draft.withFile(slot, file));
    // Anything the pick replaced, and any extra file the picker returned, is
    // discarded — a slot holds exactly one file.
    if (replaced != null) {
      await ref.read(attachmentPickerProvider).discard(replaced);
    }
    for (final RequestAttachment extra in picked.skip(1)) {
      await ref.read(attachmentPickerProvider).discard(extra);
    }
    // Persisted at once: the copy already exists on disk, and losing the
    // reference to it would leave an orphaned file behind.
    await _save(silent: true);
  }

  Future<void> _clearSlot(ApplicationFileSlot slot) async {
    final RequestAttachment? file = _draft.fileFor(slot);
    if (file == null) return;
    await ref.read(attachmentPickerProvider).discard(file);
    if (!mounted) return;
    setState(() => _draft = _draft.withFile(slot, null));
    await _save(silent: true);
  }

  Future<void> _save({bool silent = false}) async {
    await ref.read(requestsProvider.notifier).save(_draft, now: DateTime.now());
    if (!mounted || silent) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.requestsSaved)));
  }

  Future<void> _submit() async {
    setState(() => _validation = RequestValidation.validate(_draft));
    if (!_validation.isValid) return;

    // Written before sending, so a crash mid-flight cannot lose the draft —
    // and with it the idempotency key that makes a retry safe.
    await _save(silent: true);
    if (!mounted) return;

    setState(() => _submitting = true);
    final SubmissionResult result;
    try {
      result = await ref.read(requestsProvider.notifier).submit(_draft);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;
    final AppLocalizations l10n = context.l10n;

    final SubmissionResult outcome = result;
    if (outcome is SubmissionAccepted) {
      // The draft has become a case. It is removed only now, after the
      // receiving system confirmed it — never before.
      await ref.read(requestsProvider.notifier).delete(_draft.id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (BuildContext _) =>
              SubmissionResultScreen(request: outcome.request),
        ),
      );
      return;
    }

    final String message = switch (result) {
      SubmissionNotConnected() => l10n.requestsSubmitUnavailable,
      SubmissionRejected(:final String message, :final List<String> issues) =>
        message.trim().isNotEmpty
            ? message
            : (issues.isNotEmpty
                  ? l10n.requestsSubmitIncomplete
                  : l10n.requestsSubmitFailed),
      SubmissionConflict() => l10n.requestsSubmitConflict,
      SubmissionTooLarge() => l10n.requestsSubmitTooLarge,
      SubmissionRateLimited() => l10n.requestsSubmitRateLimited,
      SubmissionUnreachable() => l10n.requestsSubmitUnreachable,
      SubmissionFailed() => l10n.requestsSubmitFailed,
      // Handled above; the compiler still wants the arm.
      SubmissionAccepted() => l10n.requestsSaved,
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
          if (!ref.watch(requestsEndpointConfiguredProvider)) ...<Widget>[
            StatusBanner(
              tone: StatusTone.warning,
              icon: Icons.construction_outlined,
              title: l10n.requestsDevNoticeTitle,
              message: l10n.requestsDevNoticeBody,
            ),
            SizedBox(height: metrics.sectionGap),
          ],

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
            _LocationField(
              selected: _draft.locationId,
              errorText: _errorText(l10n, RequestField.location),
              onChanged: (int? id) => setState(
                () => _draft = _draft.copyWith(
                  locationId: id,
                  clearLocation: id == null,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              initialValue: _draft.applicant,
              decoration: InputDecoration(
                labelText: l10n.requestsFieldApplicant,
                errorText: _errorText(l10n, RequestField.applicant),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (String value) =>
                  _draft = _draft.copyWith(applicant: value),
            ),
            const SizedBox(height: AppSpacing.md),
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

          if (isFinance) ...<Widget>[
            SizedBox(height: metrics.sectionGap),
            Text(
              l10n.requestsFilesTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.requestsFilesHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_validation.errorFor(RequestField.files) != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.requestsSubmitIncomplete,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (final ApplicationFileSlot slot in ApplicationFileSlot.values)
              _FileSlotTile(
                key: ValueKey<String>('slot-${slot.field}'),
                slot: slot,
                file: _draft.fileFor(slot),
                onPick: () => _pickInto(slot),
                onClear: () => _clearSlot(slot),
              ),
          ],

          SizedBox(height: metrics.sectionGap),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: AppSpacing.sm,
            overflowSpacing: AppSpacing.xs,
            overflowAlignment: OverflowBarAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: _submitting ? null : _save,
                child: Text(l10n.requestsSave),
              ),
              FilledButton(
                // Disabled while in flight: a second tap would send the same
                // key again, and although the endpoint would replay rather
                // than duplicate, the upload itself is not free.
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _submitting ? l10n.requestsSubmitting : l10n.requestsSubmit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The location picker.
///
/// The list comes from the receiving system, so it can be missing, empty or
/// still loading — each of which is stated rather than rendered as an empty
/// dropdown the user would tap at fruitlessly.
class _LocationField extends ConsumerWidget {
  const _LocationField({
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<ApplicationLocation>> locations = ref.watch(
      applicationLocationsProvider,
    );

    return locations.when(
      loading: () => InputDecorator(
        decoration: InputDecoration(labelText: l10n.requestsFieldLocation),
        child: Text(l10n.requestsLocationsLoading),
      ),
      error: (Object error, StackTrace stack) => InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.requestsFieldLocation,
          errorText: errorText,
        ),
        child: Text(l10n.requestsLocationsUnavailable),
      ),
      data: (List<ApplicationLocation> items) {
        if (items.isEmpty) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.requestsFieldLocation,
              errorText: errorText,
            ),
            child: Text(l10n.requestsLocationsEmpty),
          );
        }
        // A stored id whose location has since disappeared must not be handed
        // to the dropdown — it would assert on a value that is not in items.
        final bool known = items.any(
          (ApplicationLocation l) => l.id == selected,
        );
        return DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: known ? selected : null,
          decoration: InputDecoration(
            labelText: l10n.requestsFieldLocation,
            errorText: errorText,
          ),
          items: <DropdownMenuItem<int>>[
            for (final ApplicationLocation location in items)
              DropdownMenuItem<int>(
                value: location.id,
                child: Text(location.name),
              ),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

/// One named file slot.
class _FileSlotTile extends StatelessWidget {
  const _FileSlotTile({
    required this.slot,
    required this.file,
    required this.onPick,
    required this.onClear,
    super.key,
  });

  final ApplicationFileSlot slot;
  final RequestAttachment? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final RequestAttachment? picked = file;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _RequestDraftScreenState.slotLabel(l10n, slot),
                  style: text.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Word, not colour: whether a slot is mandatory may not depend
              // on a shade of grey.
              Text(
                slot.isRequired
                    ? l10n.requestsSlotRequired
                    : l10n.requestsSlotOptional,
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            l10n.requestsSlotFormats(
              slot.extensions.map((String e) => e.toUpperCase()).join(' · '),
            ),
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (slot == ApplicationFileSlot.studentCard)
            Text(
              l10n.requestsStudentCardPrivacy,
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          const SizedBox(height: AppSpacing.xs),
          if (picked == null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.attach_file),
                label: Text(l10n.requestsSlotChoose),
              ),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(picked.fileName),
              subtitle: picked.sizeBytes == null
                  ? null
                  : Text(
                      _RequestDraftScreenState._formatSize(picked.sizeBytes!),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.autorenew),
                    tooltip: l10n.requestsSlotReplace,
                    onPressed: onPick,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.requestsRemoveAttachment,
                    onPressed: onClear,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
