// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/mail_search_controller.dart';
import '../domain/mail_message.dart';
import 'mail_error_messages.dart';
import 'mail_header_tile.dart';

/// Server-side mail search. Runs an IMAP SEARCH over the selected mailbox, so it
/// finds messages that are not cached locally, matching the sender and the
/// content. Results are shown on submit.
class MailSearchScreen extends ConsumerStatefulWidget {
  const MailSearchScreen({super.key});

  @override
  ConsumerState<MailSearchScreen> createState() => _MailSearchScreenState();
}

class _MailSearchScreenState extends ConsumerState<MailSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) =>
      ref.read(mailSearchControllerProvider.notifier).run(value);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final AsyncValue<List<MailMessageHeader>> results = ref.watch(
      mailSearchControllerProvider,
    );
    final String query = ref.watch(mailSearchControllerProvider.notifier).query;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: l10n.mailSearchHint,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.actionClose,
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(mailSearchControllerProvider.notifier).clear();
                      setState(() {});
                    },
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: results.when(
        loading: () => const LoadingView(),
        error: (Object error, _) => EmptyView(
          icon: Icons.error_outline,
          title: l10n.errorGenericTitle,
          message: mailFailureMessage(l10n, error),
          action: FilledButton.icon(
            onPressed: () => _submit(_controller.text),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.mailRetry),
          ),
        ),
        data: (List<MailMessageHeader> headers) {
          if (query.isEmpty) {
            return EmptyView(
              icon: Icons.search,
              title: l10n.mailSearchTooltip,
              message: l10n.mailSearchPrompt,
            );
          }
          if (headers.isEmpty) {
            return EmptyView(
              icon: Icons.search_off,
              title: l10n.mailSearchEmptyTitle,
              message: l10n.mailSearchEmpty,
            );
          }
          return ListView.separated(
            itemCount: headers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) =>
                MailHeaderTile(header: headers[index], locale: locale),
          );
        },
      ),
    );
  }
}
