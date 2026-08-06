// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/requests_controller.dart';
import '../application/requests_providers.dart';
import '../data/attachment_picker.dart';
import '../domain/application_files.dart';
import '../domain/application_location.dart';
import '../domain/request_drafts.dart';
import '../domain/request_gateway.dart';
import '../domain/request_validation.dart';
import 'request_form_parts.dart';
import 'request_status_labels.dart';

/// The finance application form.
///
/// Field order is the endpoint's order and the paper form's order: location,
/// subject, applicant, then the four files. Nothing else is asked for — no
/// amount, no category, no contact address — because the endpoint takes none
/// of them and the numbers belong in the attached PDF.
class ApplicationFormScreen extends ConsumerStatefulWidget {
  const ApplicationFormScreen({this.draftId, super.key});

  /// An existing draft to continue, or `null` to start a new one.
  final String? draftId;

  @override
  ConsumerState<ApplicationFormScreen> createState() =>
      _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends ConsumerState<ApplicationFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _applicant;

  FinanceApplicationDraft? _draft;
  bool _submitting = false;
  bool _showErrors = false;

  /// Server-side issues, kept per field so they appear where they belong.
  Map<RequestField, String> _serverErrors = <RequestField, String>{};
  List<String> _generalIssues = <String>[];
  String? _banner;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _applicant = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _title.dispose();
    _applicant.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final RequestsController controller = ref.read(requestsProvider.notifier);
    await ref.read(requestsProvider.future);
    final String? id = widget.draftId;
    final RequestDraft? existing = id == null ? null : controller.byId(id);
    final FinanceApplicationDraft draft = existing is FinanceApplicationDraft
        ? existing
        : controller.createApplication(now: DateTime.now());
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _title.text = draft.title;
      _applicant.text = draft.applicant;
    });
  }

  /// Keeps the draft on the device as the user types.
  ///
  /// Saving on every change is what makes leaving the screen safe: there is no
  /// "unsaved changes" state to lose, and a crash costs at most the last
  /// keystroke.
  Future<void> _update(
    FinanceApplicationDraft Function(FinanceApplicationDraft) change,
  ) async {
    final FinanceApplicationDraft? current = _draft;
    if (current == null || current.isFrozen) return;
    final FinanceApplicationDraft next = change(current);
    setState(() => _draft = next);
    await ref.read(requestsProvider.notifier).save(next, now: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FinanceApplicationDraft? draft = _draft;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsApplicationFormTitle)),
      body: draft == null ? const LoadingView() : _form(context, l10n, draft),
    );
  }

  Widget _form(
    BuildContext context,
    AppLocalizations l10n,
    FinanceApplicationDraft draft,
  ) {
    final RequestValidation validation = RequestValidation.validate(draft);
    final AsyncValue<List<ApplicationLocation>> locations = ref.watch(
      applicationLocationsProvider,
    );

    String? errorFor(RequestField field) {
      final String? server = _serverErrors[field];
      if (server != null && server.isNotEmpty) return server;
      if (!_showErrors) return null;
      final RequestFieldError? local = validation.errorFor(field);
      return local == null ? null : RequestLabels.fieldError(l10n, local);
    }

    return ListView(
      padding: EdgeInsets.all(context.metrics.screenPadding),
      children: <Widget>[
        if (draft.isFrozen) ...<Widget>[
          StatusBanner(
            tone: StatusTone.warning,
            icon: Icons.hourglass_top_outlined,
            title: l10n.requestsFrozenTitle,
            message: l10n.requestsFrozenBody,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (_banner != null) ...<Widget>[
          StatusBanner(
            tone: StatusTone.warning,
            icon: Icons.error_outline,
            title: _banner!,
            message: _generalIssues.join('\n'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 1 — Standort
        RequiredLabel(text: l10n.requestsFieldLocation),
        PickerField<ApplicationLocation>(
          values: locations,
          selectedId: draft.locationId,
          idOf: (ApplicationLocation l) => l.id,
          nameOf: (ApplicationLocation l) => l.name,
          loadingText: l10n.requestsLocationsLoading,
          emptyText: l10n.requestsLocationsEmpty,
          errorText: l10n.requestsLocationsUnavailable,
          retryText: l10n.requestsStatusRetry,
          enabled: !draft.isFrozen,
          onRetry: () => ref.invalidate(applicationLocationsProvider),
          onSelected: (int id) => _update(
            (FinanceApplicationDraft d) => d.copyWith(locationId: id),
          ),
          fieldError: errorFor(RequestField.location),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 2 — Antragsgegenstand
        RequiredLabel(text: l10n.requestsFieldTitle),
        TextField(
          controller: _title,
          enabled: !draft.isFrozen,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          // Enforced in the field itself, so the limit is a fact rather than a
          // message that arrives after the work is done.
          maxLength: FinanceApplicationDraft.textMaxLength,
          decoration: InputDecoration(
            hintText: l10n.requestsFieldTitleHint,
            errorText: errorFor(RequestField.title),
          ),
          onChanged: (String value) =>
              _update((FinanceApplicationDraft d) => d.copyWith(title: value)),
        ),
        const SizedBox(height: AppSpacing.md),

        // 3 — Antragsteller
        RequiredLabel(text: l10n.requestsFieldApplicant),
        TextField(
          controller: _applicant,
          enabled: !draft.isFrozen,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: FinanceApplicationDraft.textMaxLength,
          decoration: InputDecoration(
            hintText: l10n.requestsFieldApplicantHint,
            errorText: errorFor(RequestField.applicant),
          ),
          onChanged: (String value) => _update(
            (FinanceApplicationDraft d) => d.copyWith(applicant: value),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 4–7 — die vier Dateifelder in Formularreihenfolge
        for (final ApplicationFileSlot slot
            in kApplicationSlotOrder) ...<Widget>[
          FileSlotField(
            slot: slot,
            attachment: draft.fileFor(slot),
            enabled: !draft.isFrozen,
            errorText: errorFor(RequestField.forSlot(slot)),
            onPick: () => _pick(slot),
            onRemove: () => _removeFile(slot),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: AppSizes.iconSmall,
                  height: AppSizes.iconSmall,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(
            _submitting
                ? l10n.requestsSubmitting
                : l10n.requestsSubmitApplication,
          ),
        ),
      ],
    );
  }

  Future<void> _pick(ApplicationFileSlot slot) async {
    final AppLocalizations l10n = context.l10n;
    final PickResult result = await ref
        .read(attachmentPickerProvider)
        .pickFor(slot);
    if (!mounted) return;

    switch (result) {
      case PickedFile(:final RequestAttachment attachment):
        final RequestAttachment? previous = _draft?.fileFor(slot);
        await _update(
          (FinanceApplicationDraft d) => d.withFile(slot, attachment),
        );
        // Replace means the old copy is no longer referenced by anything.
        if (previous != null) {
          await ref.read(attachmentStoreProvider).delete(previous);
        }
      case PickCancelled():
        return;
      case PickWrongType():
        _showMessage(l10n.requestsSlotWrongType);
      case PickTooLarge():
        _showMessage(l10n.requestsSlotTooLarge);
      case PickFailed():
        _showMessage(l10n.requestsSubmitFailed);
    }
  }

  Future<void> _removeFile(ApplicationFileSlot slot) async {
    final RequestAttachment? existing = _draft?.fileFor(slot);
    await _update((FinanceApplicationDraft d) => d.withFile(slot, null));
    if (existing != null) {
      await ref.read(attachmentStoreProvider).delete(existing);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final FinanceApplicationDraft? draft = _draft;
    if (draft == null) return;

    final AppLocalizations l10n = context.l10n;
    setState(() {
      _showErrors = true;
      _serverErrors = <RequestField, String>{};
      _generalIssues = <String>[];
      _banner = null;
    });

    if (!RequestValidation.validate(draft).isValid) return;

    // Guards against a double tap producing two submissions.
    setState(() => _submitting = true);
    final SubmitOutcome outcome = await ref
        .read(requestsProvider.notifier)
        .submit(draft, now: DateTime.now());
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (outcome) {
      case SubmitRecorded(:final submitted):
        context.pushReplacementNamed(
          AppRoutes.requestSubmissionName,
          pathParameters: <String, String>{'id': submitted.id},
        );
      case SubmitStoreFailed():
        setState(() => _banner = l10n.requestsSubmitStoreFailed);
      case SubmitKeyExpired():
        setState(() => _banner = l10n.requestsKeyExpiredBody);
      case SubmitPayloadChanged():
        setState(() => _banner = l10n.requestsPayloadChanged);
      case SubmitGatewaySaid(:final SubmissionResult result):
        _applyGatewayResult(l10n, result);
    }
  }

  /// Puts the endpoint's own issues on the fields they name.
  ///
  /// Nothing the user typed or picked is touched here — a rejected submission
  /// leaves the form exactly as it was, which is the whole point.
  void _applyGatewayResult(AppLocalizations l10n, SubmissionResult result) {
    if (result is SubmissionRejected) {
      setState(() {
        _serverErrors = result.fieldErrors;
        _generalIssues = result.generalIssues;
        _banner = result.fieldErrors.isEmpty && result.generalIssues.isEmpty
            ? (result.message.isEmpty
                  ? l10n.requestsSubmitFailed
                  : result.message)
            : (result.message.isEmpty ? null : result.message);
      });
      return;
    }
    setState(() => _banner = RequestLabels.submissionProblem(l10n, result));
  }
}
