// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/requests_controller.dart';
import '../application/requests_providers.dart';
import '../domain/feedback_area.dart';
import '../domain/request_drafts.dart';
import '../domain/request_gateway.dart';
import '../domain/request_validation.dart';
import 'request_form_parts.dart';
import 'request_status_labels.dart';

/// The feedback form: area, an optional name, and the text.
///
/// No title field — the receiving system derives the card title from the text
/// itself — and no attachments, because the endpoint takes none.
class FeedbackFormScreen extends ConsumerStatefulWidget {
  const FeedbackFormScreen({this.draftId, super.key});

  final String? draftId;

  @override
  ConsumerState<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends ConsumerState<FeedbackFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _text;

  FeedbackDraft? _draft;
  bool _submitting = false;
  bool _showErrors = false;

  Map<RequestField, String> _serverErrors = <RequestField, String>{};
  List<String> _generalIssues = <String>[];
  String? _banner;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _text = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final RequestsController controller = ref.read(requestsProvider.notifier);
    await ref.read(requestsProvider.future);
    final String? id = widget.draftId;
    final RequestDraft? existing = id == null ? null : controller.byId(id);
    final FeedbackDraft draft = existing is FeedbackDraft
        ? existing
        : controller.createFeedback(now: DateTime.now());
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _name.text = draft.submitterName;
      _text.text = draft.feedback;
    });
  }

  Future<void> _update(FeedbackDraft Function(FeedbackDraft) change) async {
    final FeedbackDraft? current = _draft;
    if (current == null || current.isFrozen) return;
    final FeedbackDraft next = change(current);
    setState(() => _draft = next);
    await ref.read(requestsProvider.notifier).save(next, now: DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FeedbackDraft? draft = _draft;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsFeedbackFormTitle)),
      body: draft == null ? const LoadingView() : _form(context, l10n, draft),
    );
  }

  Widget _form(
    BuildContext context,
    AppLocalizations l10n,
    FeedbackDraft draft,
  ) {
    final RequestValidation validation = RequestValidation.validate(draft);
    final AsyncValue<List<FeedbackArea>> areas = ref.watch(
      feedbackAreasProvider,
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

        // 1 — Bereich
        RequiredLabel(text: l10n.requestsFieldArea),
        PickerField<FeedbackArea>(
          values: areas,
          selectedId: draft.areaId,
          idOf: (FeedbackArea a) => a.id,
          nameOf: (FeedbackArea a) => a.name,
          loadingText: l10n.requestsAreasLoading,
          emptyText: l10n.requestsAreasEmpty,
          errorText: l10n.requestsAreasUnavailable,
          retryText: l10n.requestsStatusRetry,
          enabled: !draft.isFrozen,
          onRetry: () => ref.invalidate(feedbackAreasProvider),
          onSelected: (int id) =>
              _update((FeedbackDraft d) => d.copyWith(areaId: id)),
          fieldError: errorFor(RequestField.area),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 2 — Dein Name (optional)
        RequiredLabel(text: l10n.requestsFieldSubmitterName, isRequired: false),
        TextField(
          controller: _name,
          enabled: !draft.isFrozen,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          maxLength: FeedbackDraft.nameMaxLength,
          decoration: InputDecoration(
            hintText: l10n.requestsFieldSubmitterNameHint,
            errorText: errorFor(RequestField.submitterName),
          ),
          onChanged: (String value) =>
              _update((FeedbackDraft d) => d.copyWith(submitterName: value)),
        ),
        Text(
          l10n.requestsSubmitterNameNote,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 3 — Dein Feedback
        RequiredLabel(text: l10n.requestsFieldFeedback),
        TextField(
          controller: _text,
          enabled: !draft.isFrozen,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          minLines: 7,
          maxLines: null,
          maxLength: FeedbackDraft.textMaxLength,
          decoration: InputDecoration(
            hintText: l10n.requestsFieldFeedbackHint,
            helperText: l10n.requestsFeedbackCounter,
            errorText: errorFor(RequestField.feedback),
            alignLabelWithHint: true,
          ),
          onChanged: (String value) =>
              _update((FeedbackDraft d) => d.copyWith(feedback: value)),
        ),

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
            _submitting ? l10n.requestsSubmitting : l10n.requestsSubmitFeedback,
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final FeedbackDraft? draft = _draft;
    if (draft == null) return;

    final AppLocalizations l10n = context.l10n;
    setState(() {
      _showErrors = true;
      _serverErrors = <RequestField, String>{};
      _generalIssues = <String>[];
      _banner = null;
    });

    if (!RequestValidation.validate(draft).isValid) return;

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
        if (result is SubmissionRejected) {
          setState(() {
            _serverErrors = result.fieldErrors;
            _generalIssues = result.generalIssues;
            _banner = result.message.isEmpty ? null : result.message;
          });
        } else {
          setState(
            () => _banner = RequestLabels.submissionProblem(l10n, result),
          );
        }
    }
  }
}
