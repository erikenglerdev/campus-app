// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/safe_link_launcher.dart';
import '../../../core/network/loaded.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/content_blocks_view.dart';
import '../../../core/widgets/icon_keys.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/remote_image.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../../campusmap/presentation/room_link.dart';
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
      padding: EdgeInsets.all(context.metrics.screenPadding),
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
        // The area's own picture, above its name. Absent for most areas, and
        // that is fine — the icon identifies them on its own.
        if (area.imageUrl != null) ...<Widget>[
          RemoteImage(
            url: area.imageUrl!,
            alternativeText: area.name,
            aspectRatio: 16 / 9,
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
        // Outside the block above on purpose: a room is not a contact channel.
        // An area may well have a room and no e-mail at all, and the way into
        // the floor plan must not disappear with the contact rows.
        // Renders nothing when the area has no room.
        RoomLinkSection(rooms: area.rooms),
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
            _PersonTile(person: person),
            const SizedBox(height: AppSpacing.sm),
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

/// A compact, tappable row for one person: name + role only. Tapping it opens
/// the full details in a bottom sheet, so the list stays scannable while every
/// field the editorial team maintains stays one tap away.
class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});

  final ContactPerson person;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(person.name, style: text.titleSmall),
        subtitle: person.role != null ? Text(person.role!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showContactPersonDetails(context, person),
      ),
    );
  }
}

/// Opens the full details of [person] in a modal bottom sheet.
Future<void> showContactPersonDetails(
  BuildContext context,
  ContactPerson person,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext _) => _PersonDetailsSheet(person: person),
  );
}

/// Every field the API delivers for one person: photo, name, role, description
/// and the contact channels. A field that is not maintained is hidden, never
/// shown as an empty row.
class _PersonDetailsSheet extends StatelessWidget {
  const _PersonDetailsSheet({required this.person});

  final ContactPerson person;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasChannels =
        person.email != null || person.phone != null || person.website != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: SheetBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (person.profileImageUrl != null) ...<Widget>[
              Center(
                child: SizedBox(
                  width: AppSizes.illustrationIcon * 2,
                  child: ClipOval(
                    child: RemoteImage(
                      url: person.profileImageUrl!,
                      alternativeText: person.name,
                      aspectRatio: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Semantics(
              header: true,
              child: Text(person.name, style: text.headlineSmall),
            ),
            if (person.role != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                person.role!,
                style: text.titleSmall?.copyWith(color: colors.textSecondary),
              ),
            ],
            if (person.description != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(person.description!, style: text.bodyMedium),
            ],
            if (hasChannels) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
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
            // Renders nothing when the person has no room.
            RoomLinkSection(rooms: person.rooms),
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
