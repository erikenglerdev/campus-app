// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/loaded.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../application/campus_map_providers.dart';
import '../application/room_search.dart';
import '../domain/map_catalog.dart';
import '../domain/room.dart';
import 'floor_map_view.dart';
import 'room_labels.dart';

/// The campus map: a zoomable fictional demo floor plan with room search.
///
/// Room names and editorial texts come from the Campus API and are cached for
/// offline use; the geometry is a bundled, generated asset. Selecting a room —
/// by search or through a contact deep link — opens the matching floor and
/// highlights it.
class CampusMapScreen extends ConsumerStatefulWidget {
  const CampusMapScreen({this.initialRoomKey, super.key});

  /// Set by the in-app deep link from a contact.
  final String? initialRoomKey;

  @override
  ConsumerState<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends ConsumerState<CampusMapScreen> {
  final TextEditingController _search = TextEditingController();
  final GlobalKey<FloorMapViewState> _mapKey = GlobalKey<FloorMapViewState>();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialRoomKey;
    if (initial != null && initial.isNotEmpty) {
      // Providers must not be written during initState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(selectedRoomProvider.notifier).select(initial);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(Room room) {
    ref.read(selectedRoomProvider.notifier).select(room.roomKey);
    ref.read(visibleFloorProvider.notifier).show(room.floorKey);
    FocusScope.of(context).unfocus();
  }

  void _clearSelection() {
    ref.read(selectedRoomProvider.notifier).clear();
    _mapKey.currentState?.resetView();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<Room>>> rooms = ref.watch(roomsProvider);
    final AsyncValue<MapCatalog> catalog = ref.watch(mapCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.campusMapTitle),
        actions: <Widget>[
          IconButton(
            onPressed: _clearSelection,
            icon: const Icon(Icons.zoom_out_map),
            tooltip: l10n.campusMapResetZoom,
          ),
        ],
      ),
      body: switch (rooms) {
        AsyncLoading<Loaded<List<Room>>>() when !rooms.hasValue =>
          const LoadingView(),
        AsyncError<Loaded<List<Room>>>(:final Object error) => ErrorView(
          failure: error,
          onRetry: () => ref.invalidate(roomsProvider),
        ),
        _ => _Body(
          loaded: rooms.requireValue,
          catalog: catalog,
          query: _query,
          search: _search,
          mapKey: _mapKey,
          onQueryChanged: (String value) => setState(() => _query = value),
          onSelect: _select,
          onClearSelection: _clearSelection,
        ),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.loaded,
    required this.catalog,
    required this.query,
    required this.search,
    required this.mapKey,
    required this.onQueryChanged,
    required this.onSelect,
    required this.onClearSelection,
  });

  final Loaded<List<Room>> loaded;
  final AsyncValue<MapCatalog> catalog;
  final String query;
  final TextEditingController search;
  final GlobalKey<FloorMapViewState> mapKey;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Room> onSelect;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<Room> allRooms = loaded.value;
    final String? selectedKey = ref.watch(selectedRoomProvider);
    final String? explicitFloor = ref.watch(visibleFloorProvider);

    final Room? selectedRoom = _firstWhereOrNull(
      allRooms,
      (Room room) => room.roomKey == selectedKey,
    );
    final List<Room> results = searchRooms(allRooms, query);

    final MapCatalog? map = catalog.value;
    final bool versionMismatch =
        map != null &&
        allRooms.isNotEmpty &&
        !map.supportsMapVersion(allRooms.first.mapVersion);

    final String? floorKey =
        explicitFloor ??
        selectedRoom?.floorKey ??
        _defaultFloorKey(map, allRooms);
    final MapFloor? floor = floorKey == null ? null : map?.floor(floorKey);
    final MapRoomGeometry? geometry = selectedKey == null
        ? null
        : map?.geometryFor(selectedKey);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        StatusBanner(
          title: l10n.campusMapTitle,
          message: l10n.campusMapDemoNotice,
          icon: Icons.info_outline,
        ),
        const SizedBox(height: AppSpacing.md),

        if (loaded.fromCache) ...<Widget>[
          OfflineNotice(cachedAt: loaded.cachedAt),
          const SizedBox(height: AppSpacing.md),
        ],

        if (catalog.hasError) ...<Widget>[
          StatusBanner(
            title: l10n.campusMapUnavailable,
            tone: StatusTone.warning,
            icon: Icons.map_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        if (versionMismatch) ...<Widget>[
          StatusBanner(
            title: l10n.campusMapTitle,
            message: l10n.campusMapVersionMismatch,
            tone: StatusTone.warning,
            icon: Icons.sync_problem_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        TextField(
          controller: search,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: l10n.campusMapSearchLabel,
            hintText: l10n.campusMapSearchHint,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.campusMapSearchClear,
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      search.clear();
                      onQueryChanged('');
                    },
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        if (map != null && !versionMismatch)
          _FloorPicker(
            catalog: map,
            rooms: allRooms,
            selectedFloorKey: floorKey,
          ),

        if (floor != null && !versionMismatch) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: FloorMapView(
                  key: mapKey,
                  floor: floor,
                  selected: geometry?.floorKey == floor.floorKey
                      ? geometry
                      : null,
                ),
              ),
            ),
          ),
        ],

        if (selectedRoom != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _SelectedRoomCard(
            room: selectedRoom,
            onMap: geometry != null,
            onClear: onClearSelection,
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.campusMapRoomCount(results.length),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),

        if (allRooms.isEmpty)
          EmptyView(
            icon: Icons.map_outlined,
            title: l10n.campusMapEmpty,
            message: l10n.campusMapDemoNotice,
          )
        else if (results.isEmpty)
          EmptyView(
            icon: Icons.search_off,
            title: l10n.campusMapNoResults,
            message: l10n.campusMapNoResultsHint,
          )
        else
          ...results.map(
            (Room room) => _RoomTile(
              room: room,
              selected: room.roomKey == selectedKey,
              onTap: () => onSelect(room),
            ),
          ),
      ],
    );
  }

  static String? _defaultFloorKey(MapCatalog? map, List<Room> rooms) {
    if (map != null && map.floors.isNotEmpty) return map.floors.first.floorKey;
    return rooms.isEmpty ? null : rooms.first.floorKey;
  }
}

/// Building and floor selection.
///
/// There is only one demo building today, so the picker stays out of the way
/// when there is nothing to choose — but the data model and this widget both
/// handle several buildings and floors without a change.
class _FloorPicker extends ConsumerWidget {
  const _FloorPicker({
    required this.catalog,
    required this.rooms,
    required this.selectedFloorKey,
  });

  final MapCatalog catalog;
  final List<Room> rooms;
  final String? selectedFloorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (catalog.floors.length < 2) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;

    return DropdownButtonFormField<String>(
      initialValue: selectedFloorKey,
      decoration: InputDecoration(
        labelText: l10n.campusMapFloorLabel,
        border: const OutlineInputBorder(),
      ),
      items: catalog.floors
          .map(
            (MapFloor floor) => DropdownMenuItem<String>(
              value: floor.floorKey,
              child: Text(_floorName(floor)),
            ),
          )
          .toList(),
      onChanged: (String? value) {
        if (value != null) ref.read(visibleFloorProvider.notifier).show(value);
      },
    );
  }

  /// The localised floor name comes from the API; the key is the fallback.
  String _floorName(MapFloor floor) {
    for (final Room room in rooms) {
      if (room.floorKey == floor.floorKey && room.floorName.isNotEmpty) {
        return room.floorName;
      }
    }
    return floor.floorKey;
  }
}

class _SelectedRoomCard extends StatelessWidget {
  const _SelectedRoomCard({
    required this.room,
    required this.onMap,
    required this.onClear,
  });

  final Room room;
  final bool onMap;
  final VoidCallback onClear;

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
            // The selection is stated in words as well, never by colour alone.
            Semantics(
              label: l10n.campusMapSemanticSelectedRoom(room.roomNumber),
              child: Text(
                l10n.campusMapSelectedRoom(room.primaryLabel),
                style: text.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              roomLocationSummary(
                context,
                buildingName: room.buildingName,
                floorName: room.floorName,
                roomNumber: room.roomNumber,
              ),
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l10n.campusMapRoomTypeLabel}: ${roomTypeLabel(context, room.roomType)}',
              style: text.bodySmall,
            ),
            if (room.description != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(room.description!, style: text.bodyMedium),
            ],
            if (!onMap) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.campusMapRoomNotOnMap,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.fullscreen_exit),
                label: Text(l10n.campusMapShowWholeFloor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.selected,
    required this.onTap,
  });

  final Room room;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ListTile(
      // Selection is carried by the icon and by the semantic flag as well, so
      // it never depends on colour alone.
      leading: Icon(
        selected ? Icons.place : Icons.meeting_room_outlined,
        semanticLabel: selected
            ? l10n.campusMapSelectedRoom(room.roomNumber)
            : null,
      ),
      title: Text(room.primaryLabel),
      subtitle: Text(
        '${room.roomNumber} · ${roomTypeLabel(context, room.roomType)} · ${room.floorName}',
      ),
      selected: selected,
      trailing: const Icon(Icons.chevron_right),
      minTileHeight: AppSizes.minTouchTarget,
      onTap: onTap,
    );
  }
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final T item in items) {
    if (test(item)) return item;
  }
  return null;
}
