// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/safe_link_launcher.dart';
import '../../../core/network/loaded.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/content_blocks_view.dart';
import '../../../core/widgets/icon_keys.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/contacts_providers.dart';
import '../data/contact_models.dart';

/// Detail view of a contact area.
///
/// An area **without** persons stays fully usable, and any field the editorial
/// team has not maintained is hidden instead of shown as an empty row.
class ContactAreaScreen extends ConsumerWidget {
  const ContactAreaScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<ContactArea>> area = ref.watch(
      contactAreaProvider(slug),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.contactsTitle)),
      body: switch (area) {
        AsyncLoading<Loaded<ContactArea>>() when !area.hasValue =>
          const LoadingView(),
        AsyncError<Loaded<ContactArea>>(:final Object error) => ErrorView(
          failure: error,
          onRetry: () => ref.invalidate(contactAreaProvider(slug)),
        ),
        _ => _AreaDetail(loaded: area.requireValue),
      },
    );
  }
}

class _AreaDetail extends StatelessWidget {
  const _AreaDetail({required this.loaded});

  final Loaded<ContactArea> loaded;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final ContactArea area = loaded.value;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        if (loaded.fromCache) ...<Widget>[
          OfflineNotice(cachedAt: loaded.cachedAt),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (area.isDemoContent) ...<Widget>[
          StatusBanner(
            icon: Icons.science_outlined,
            title: l10n.contactsDemoBadge,
            message: l10n.contactsDemoHint,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(IconKeys.resolve(area.iconKey), size: AppSizes.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(area.name, style: text.headlineSmall),
              ),
            ),
          ],
        ),
        if (area.shortDescription != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(area.shortDescription!, style: text.bodyLarge),
        ],
        if (area.description.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          ContentBlocksView(blocks: area.description),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (area.hasContactDetails)
          _ContactDetails(area: area)
        else
          Text(l10n.contactNoContactDetailsMessage, style: text.bodyMedium),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(l10n.contactPersonsLabel, style: text.titleMedium),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (area.persons.isEmpty)
          Text(l10n.contactNoPersonsMessage, style: text.bodyMedium)
        else
          for (final ContactPerson person in area.persons) ...<Widget>[
            _PersonCard(person: person),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({required this.area});

  final ContactArea area;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Every row below is conditional: a field that is not maintained is
        // hidden entirely, never rendered as an empty row.
        if (area.generalEmail != null)
          ContactActionTile(
            icon: Icons.mail_outline,
            label: l10n.contactEmailLabel,
            value: area.generalEmail!,
            uri: mailtoUri(area.generalEmail),
          ),
        if (area.phone != null)
          ContactActionTile(
            icon: Icons.phone_outlined,
            label: l10n.contactPhoneLabel,
            value: area.phone!,
            uri: telUri(area.phone),
          ),
        if (area.website != null)
          ContactActionTile(
            icon: Icons.language_outlined,
            label: l10n.contactWebsiteLabel,
            value: area.website!,
            uri: Uri.tryParse(area.website!),
          ),
        if (area.appointmentUrl != null)
          ContactActionTile(
            icon: Icons.event_available_outlined,
            label: l10n.contactAppointmentLabel,
            value: area.appointmentUrl!,
            uri: Uri.tryParse(area.appointmentUrl!),
          ),
        if (area.address != null)
          ContactActionTile(
            icon: Icons.place_outlined,
            label: l10n.contactAddressLabel,
            value: area.address!,
          ),
        if (area.openingHours != null)
          ContactActionTile(
            icon: Icons.schedule_outlined,
            label: l10n.contactOpeningHoursLabel,
            value: area.openingHours!,
          ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.person});

  final ContactPerson person;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(person.name, style: text.titleSmall),
            if (person.role != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(person.role!, style: text.bodySmall),
            ],
            if (person.description != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(person.description!, style: text.bodyMedium),
            ],
            if (person.email != null)
              ContactActionTile(
                icon: Icons.mail_outline,
                label: l10n.contactEmailLabel,
                value: person.email!,
                uri: mailtoUri(person.email),
              ),
            if (person.phone != null)
              ContactActionTile(
                icon: Icons.phone_outlined,
                label: l10n.contactPhoneLabel,
                value: person.phone!,
                uri: telUri(person.phone),
              ),
            if (person.website != null)
              ContactActionTile(
                icon: Icons.language_outlined,
                label: l10n.contactWebsiteLabel,
                value: person.website!,
                uri: Uri.tryParse(person.website!),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single contact row. Tappable only when a safe [uri] exists.
class ContactActionTile extends ConsumerWidget {
  const ContactActionTile({
    required this.icon,
    required this.label,
    required this.value,
    this.uri,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Uri? uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      onTap: uri == null
          ? null
          : () async {
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                context,
              );
              final LinkLaunchResult result = await ref
                  .read(linkLauncherProvider)
                  .open(uri.toString());
              if (result == LinkLaunchResult.opened) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    result == LinkLaunchResult.blocked
                        ? l10n.errorLinkBlocked
                        : l10n.errorLinkNotOpened,
                  ),
                ),
              );
            },
    );
  }
}
