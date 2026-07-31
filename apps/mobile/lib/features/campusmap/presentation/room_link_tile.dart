// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../contacts/data/contact_models.dart';
import '../application/campus_map_providers.dart';
import '../domain/map_catalog.dart';

/// One room row inside contact details.
///
/// Tapping opens the campus map with the room selected. When the bundled map
/// does not know the roomKey — an older app with a newer catalogue — the row
/// stays as plain, readable text instead of leading to an empty map.
class RoomLinkTile extends ConsumerWidget {
  const RoomLinkTile({required this.room, super.key});

  final RoomReference room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final MapCatalog? catalog = ref.watch(mapCatalogProvider).value;
    final bool onMap = catalog?.geometryFor(room.roomKey) != null;

    final String summary = l10n.contactRoomSummary(
      room.buildingName,
      room.floorName,
      room.roomNumber,
    );

    return ListTile(
      leading: const Icon(Icons.place_outlined),
      title: Text(room.displayName ?? room.roomNumber),
      subtitle: Text(
        onMap ? summary : '$summary\n${l10n.campusMapRoomNotOnMap}',
      ),
      isThreeLine: !onMap,
      trailing: onMap ? const Icon(Icons.chevron_right) : null,
      minTileHeight: AppSizes.minTouchTarget,
      onTap: onMap
          ? () => context.push(AppRoutes.campusMapForRoom(room.roomKey))
          : null,
    );
  }
}

/// The rooms of a contact, with a heading. Renders nothing when there are none,
/// so a contact without a room looks exactly as it did before.
class RoomLinkSection extends StatelessWidget {
  const RoomLinkSection({required this.rooms, super.key});

  final List<RoomReference> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.contactRoomsLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        ...rooms.map((RoomReference room) => RoomLinkTile(room: room)),
      ],
    );
  }
}
