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
/// The plan is FULL-BLEED and everything else floats above it, the way a map
/// application behaves — the map is the content, not a thumbnail wedged between
/// form fields. Search, results and room details appear when they are needed
/// and get out of the way when they are not.
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

/// Heights of the floating panels.
///
/// The map lies behind them, so these values also decide where a selected room
/// is centred — see [FloorMapView.visiblePadding].
const double kSearchBarHeight = 56;
const double kDemoBadgeHeight = 40;
const double kDetailSheetHeight = 236;
const double kResultsBarHeight = 76;

class _CampusMapScreenState extends ConsumerState<CampusMapScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
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
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(Room room) {
    ref.read(selectedRoomProvider.notifier).select(room.roomKey);
    ref.read(visibleFloorProvider.notifier).show(room.floorKey);
    // Picking a result closes the search, the way a map app hands the screen
    // back to the map once you have chosen a destination.
    _search.clear();
    setState(() => _query = '');
    _searchFocus.unfocus();
  }

  void _clearSelection() {
    ref.read(selectedRoomProvider.notifier).clear();
    _mapKey.currentState?.resetView();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Loaded<List<Room>>> rooms = ref.watch(roomsProvider);

    return Scaffold(
      body: switch (rooms) {
        AsyncLoading<Loaded<List<Room>>>() when !rooms.hasValue =>
          const LoadingView(),
        AsyncError<Loaded<List<Room>>>(:final Object error) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ErrorView(
            failure: error,
            onRetry: () => ref.invalidate(roomsProvider),
          ),
        ),
        _ => _MapSurface(
          loaded: rooms.requireValue,
          query: _query,
          search: _search,
          searchFocus: _searchFocus,
          mapKey: _mapKey,
          onQueryChanged: (String value) => setState(() => _query = value),
          onSelect: _select,
          onClearSelection: _clearSelection,
        ),
      },
    );
  }
}

class _MapSurface extends ConsumerWidget {
  const _MapSurface({
    required this.loaded,
    required this.query,
    required this.search,
    required this.searchFocus,
    required this.mapKey,
    required this.onQueryChanged,
    required this.onSelect,
    required this.onClearSelection,
  });

  final Loaded<List<Room>> loaded;
  final String query;
  final TextEditingController search;
  final FocusNode searchFocus;
  final GlobalKey<FloorMapViewState> mapKey;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Room> onSelect;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Room> allRooms = loaded.value;
    final String? selectedKey = ref.watch(selectedRoomProvider);
    final String? explicitBuilding = ref.watch(visibleBuildingProvider);
    final String? explicitFloor = ref.watch(visibleFloorProvider);
    final MapCatalog? map = ref.watch(mapCatalogProvider).value;

    final Room? selectedRoom = _firstWhereOrNull(
      allRooms,
      (Room room) => room.roomKey == selectedKey,
    );
    final List<Room> results = query.isEmpty
        ? const <Room>[]
        : searchRooms(allRooms, query);

    final bool versionMismatch =
        map != null &&
        allRooms.isNotEmpty &&
        !map.supportsMapVersion(allRooms.first.mapVersion);

    // Derived rather than trusted. The controllers keep building and floor
    // consistent when they are written, but the map must also survive a state
    // that never was: a floor from another building would otherwise draw a plan
    // that contradicts the building shown above it.
    final String? buildingKey = _visibleBuildingKey(
      map: map,
      explicitBuilding: explicitBuilding,
      explicitFloor: explicitFloor,
      selectedRoom: selectedRoom,
      rooms: allRooms,
    );
    final String? floorKey = _visibleFloorKey(
      map: map,
      buildingKey: buildingKey,
      explicitFloor: explicitFloor,
      selectedRoom: selectedRoom,
      rooms: allRooms,
    );
    final MapFloor? floor = floorKey == null ? null : map?.floor(floorKey);
    final MapRoomGeometry? geometry = selectedKey == null
        ? null
        : map?.geometryFor(selectedKey);

    final bool mapUsable = floor != null && !versionMismatch;
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    // What the overlays cover, so a selected room is centred in the part of the
    // plan that is actually visible rather than behind a panel.
    final EdgeInsets covered = EdgeInsets.only(
      top: safe.top + kSearchBarHeight + kDemoBadgeHeight + AppSpacing.xl,
      bottom:
          safe.bottom +
          (selectedRoom != null ? kDetailSheetHeight : kResultsBarHeight),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: mapUsable
              ? FloorMapView(
                  key: mapKey,
                  floor: floor,
                  selected: geometry?.floorKey == floor.floorKey
                      ? geometry
                      : null,
                  visiblePadding: covered,
                )
              : _MapUnavailable(versionMismatch: versionMismatch),
        ),

        _TopOverlay(
          loaded: loaded,
          query: query,
          search: search,
          searchFocus: searchFocus,
          results: results,
          onSelect: onSelect,
          onQueryChanged: onQueryChanged,
          planKind: map?.building(buildingKey)?.planKind ?? PlanKind.fictional,
        ),

        // Hidden while searching so the results overlay keeps the screen.
        if (mapUsable && map != null && buildingKey != null && query.isEmpty)
          _MapControls(
            map: map,
            buildingKey: buildingKey,
            floorKey: floor.floorKey,
            top: covered.top,
          ),

        if (mapUsable && selectedRoom == null && query.isEmpty)
          _ResetButton(
            bottom: safe.bottom + kResultsBarHeight + AppSpacing.lg,
            onPressed: () => mapKey.currentState?.resetView(),
          ),

        if (selectedRoom != null)
          _RoomDetailSheet(
            room: selectedRoom,
            onMap: geometry != null,
            onClose: onClearSelection,
          )
        else if (query.isEmpty)
          _ResultsBar(rooms: allRooms, onSelect: onSelect),
      ],
    );
  }

  /// Which building the map is showing.
  ///
  /// An explicit choice wins; otherwise the selected room decides, so a deep
  /// link lands on the right building even before anyone has touched the
  /// picker — and even while the bundled catalogue is still loading.
  static String? _visibleBuildingKey({
    required MapCatalog? map,
    required String? explicitBuilding,
    required String? explicitFloor,
    required Room? selectedRoom,
    required List<Room> rooms,
  }) {
    if (map == null) return null;
    if (map.building(explicitBuilding) != null) return explicitBuilding;
    final String? fromFloor = map.buildingOfFloor(explicitFloor);
    if (fromFloor != null) return fromFloor;
    final String? fromRoom =
        map.geometryFor(selectedRoom?.roomKey ?? '')?.buildingKey ??
        map.buildingOfFloor(selectedRoom?.floorKey);
    if (fromRoom != null) return fromRoom;
    return map.buildings.isNotEmpty
        ? map.buildings.first.buildingKey
        : map.buildingOfFloor(rooms.isEmpty ? null : rooms.first.floorKey);
  }

  /// Which floor of that building the map is showing.
  ///
  /// Anything that does not belong to [buildingKey] is ignored rather than
  /// drawn: the picker above the map states a building, and the plan below it
  /// has to agree.
  static String? _visibleFloorKey({
    required MapCatalog? map,
    required String? buildingKey,
    required String? explicitFloor,
    required Room? selectedRoom,
    required List<Room> rooms,
  }) {
    if (map == null || buildingKey == null) {
      return explicitFloor ?? selectedRoom?.floorKey;
    }
    final List<MapFloor> floors = map.floorsOf(buildingKey);
    bool belongs(String? key) =>
        key != null && floors.any((MapFloor f) => f.floorKey == key);

    if (belongs(explicitFloor)) return explicitFloor;
    if (belongs(selectedRoom?.floorKey)) return selectedRoom!.floorKey;
    return floors.isEmpty ? null : floors.first.floorKey;
  }
}

/// Shown instead of the plan when it cannot be drawn.
class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.versionMismatch});

  final bool versionMismatch;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: StatusBanner(
            title: l10n.campusMapTitle,
            message: versionMismatch
                ? l10n.campusMapVersionMismatch
                : l10n.campusMapUnavailable,
            tone: StatusTone.warning,
            icon: Icons.map_outlined,
          ),
        ),
      ),
    );
  }
}

/// Floating search bar, demo badge and — while typing — the result list.
class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.loaded,
    required this.query,
    required this.search,
    required this.searchFocus,
    required this.results,
    required this.onSelect,
    required this.onQueryChanged,
    required this.planKind,
  });

  final Loaded<List<Room>> loaded;
  final String query;
  final TextEditingController search;
  final FocusNode searchFocus;
  final List<Room> results;
  final ValueChanged<Room> onSelect;
  final ValueChanged<String> onQueryChanged;
  final PlanKind planKind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SearchBar(
              query: query,
              controller: search,
              focusNode: searchFocus,
              onQueryChanged: onQueryChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            _PlanBadge(kind: planKind),
            if (loaded.fromCache) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              OfflineNotice(cachedAt: loaded.cachedAt),
            ],
            if (query.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: _ResultsOverlay(
                  results: results,
                  onSelect: onSelect,
                  emptyTitle: l10n.campusMapNoResults,
                  emptyMessage: l10n.campusMapNoResultsHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.query,
    required this.controller,
    required this.focusNode,
    required this.onQueryChanged,
  });

  final String query;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final MaterialLocalizations material = MaterialLocalizations.of(context);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: kSearchBarHeight,
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: material.backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  // The bar carries no visible label, so the hint doubles as
                  // the accessible name of the field.
                  hintText: l10n.campusMapSearchLabel,
                ),
              ),
            ),
            if (query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: l10n.campusMapSearchClear,
                onPressed: () {
                  controller.clear();
                  onQueryChanged('');
                },
              )
            else
              const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// Always-visible statement of what the plan on screen actually is, with the
/// full wording one tap away.
///
/// The text follows the building, because the two plans make different claims:
/// the demo floor plan is invented, the campus overview is a simplified view of
/// a real site and explicitly not an escape or official site plan. A single
/// fixed badge would be wrong for one of them.
class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.kind});

  final PlanKind kind;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String title = switch (kind) {
      PlanKind.fictional => l10n.campusMapDemoBadge,
      PlanKind.schematic => l10n.campusMapSchematicBadge,
    };
    final String notice = switch (kind) {
      PlanKind.fictional => l10n.campusMapDemoNotice,
      PlanKind.schematic => l10n.campusMapSchematicNotice,
    };

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (BuildContext dialogContext) => AlertDialog(
              icon: const Icon(Icons.info_outline),
              title: Text(title),
              content: Text(notice),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    MaterialLocalizations.of(dialogContext).closeButtonLabel,
                  ),
                ),
              ],
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kDemoBadgeHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: AppSizes.iconSmall,
                    color: colors.onSecondaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The search results, floating under the search bar.
class _ResultsOverlay extends StatelessWidget {
  const _ResultsOverlay({
    required this.results,
    required this.onSelect,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<Room> results;
  final ValueChanged<Room> onSelect;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(emptyTitle, style: text.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(emptyMessage, style: text.bodySmall),
                ],
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: results.length,
              itemBuilder: (BuildContext context, int index) => _RoomTile(
                room: results[index],
                onTap: () => onSelect(results[index]),
              ),
            ),
    );
  }
}

/// Resting state at the bottom: how many rooms exist, and a way into the list.
class _ResultsBar extends StatelessWidget {
  const _ResultsBar({required this.rooms, required this.onSelect});

  final List<Room> rooms;
  final ValueChanged<Room> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 8,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: kResultsBarHeight,
            child: rooms.isEmpty
                ? Center(
                    child: Text(l10n.campusMapEmpty, style: text.bodyMedium),
                  )
                : InkWell(
                    onTap: () => showAllRooms(context, rooms, onSelect),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.list),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              l10n.campusMapRoomCount(rooms.length),
                              style: text.titleSmall,
                            ),
                          ),
                          Text(
                            l10n.campusMapShowAllRooms,
                            style: text.labelLarge,
                          ),
                          const Icon(Icons.expand_less),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The full room list as a draggable sheet.
Future<void> showAllRooms(
  BuildContext context,
  List<Room> rooms,
  ValueChanged<Room> onSelect,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (BuildContext context, ScrollController controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                context.l10n.campusMapRoomCount(rooms.length),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: rooms.length,
              itemBuilder: (BuildContext context, int index) => _RoomTile(
                room: rooms[index],
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onSelect(rooms[index]);
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Details of the selected room, anchored at the bottom like a map app.
class _RoomDetailSheet extends StatelessWidget {
  const _RoomDetailSheet({
    required this.room,
    required this.onMap,
    required this.onClose,
  });

  final Room room;
  final bool onMap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 8,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // The selection is carried by an icon as well, never by
                    // colour alone.
                    Icon(Icons.place, color: colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Semantics(
                        label: l10n.campusMapSemanticSelectedRoom(
                          room.roomNumber,
                        ),
                        child: Text(
                          l10n.campusMapSelectedRoom(room.primaryLabel),
                          style: text.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: l10n.campusMapShowWholeFloor,
                      onPressed: onClose,
                    ),
                  ],
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
                  '${l10n.campusMapRoomTypeLabel}: '
                  '${roomTypeLabel(context, room.roomType)}',
                  style: text.bodySmall,
                ),
                if (room.description != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    room.description!,
                    style: text.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (!onMap) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.campusMapRoomNotOnMap,
                    style: text.bodySmall?.copyWith(color: colors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
                    onPressed: onClose,
                    icon: const Icon(Icons.fullscreen_exit),
                    label: Text(l10n.campusMapShowWholeFloor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Building and floor pickers, floating on the map like a layer switch.
///
/// Building sits above floor because a floor only means something inside its
/// building — the wider choice is made first, and the narrower one follows.
///
/// Both are driven entirely by the bundled catalogue. There is deliberately no
/// key-to-label mapping in this file: another building or floor is a catalogue
/// change, never a Flutter change.
class _MapControls extends ConsumerWidget {
  const _MapControls({
    required this.map,
    required this.buildingKey,
    required this.floorKey,
    required this.top,
  });

  final MapCatalog map;
  final String buildingKey;
  final String floorKey;
  final double top;

  /// Long names must not push the control across the map, and the map is
  /// narrow on a phone — so the label ellipsises instead of growing.
  static const double _maxLabelWidth = 168;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final List<MapFloor> floors = map.floorsOf(buildingKey);
    final MapBuilding? building = map.building(buildingKey);
    final MapFloor? current = floors.isEmpty
        ? null
        : floors.firstWhere(
            (MapFloor floor) => floor.floorKey == floorKey,
            orElse: () => floors.first,
          );

    return PositionedDirectional(
      end: AppSpacing.lg,
      top: top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Only worth a control when there is something to choose.
          if (map.hasSeveralBuildings && building != null) ...<Widget>[
            _MapChoice<String>(
              icon: Icons.apartment_outlined,
              label: building.name.resolve(locale),
              tooltip: l10n.campusMapBuildingLabel,
              semanticLabel: l10n.campusMapBuildingSelectorSemantic(
                building.name.resolve(locale),
              ),
              value: building.buildingKey,
              options: <({String value, String label})>[
                for (final MapBuilding candidate in map.buildings)
                  (
                    value: candidate.buildingKey,
                    label: candidate.name.resolve(locale),
                  ),
              ],
              onSelected: (String key) =>
                  ref.read(visibleBuildingProvider.notifier).show(key),
              maxLabelWidth: _maxLabelWidth,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Shown even for a single level, so the structure the map now has is
          // visible rather than something the user has to discover. With one
          // option it is a plain, non-interactive chip.
          if (current != null)
            _MapChoice<String>(
              icon: Icons.layers_outlined,
              label: current.name.resolve(locale),
              tooltip: l10n.campusMapFloorLabel,
              semanticLabel: floors.length > 1
                  ? l10n.campusMapFloorSelectorSemantic(
                      current.name.resolve(locale),
                    )
                  : l10n.campusMapSingleFloorSemantic(
                      current.name.resolve(locale),
                    ),
              value: current.floorKey,
              options: <({String value, String label})>[
                for (final MapFloor floor in floors)
                  (value: floor.floorKey, label: floor.name.resolve(locale)),
              ],
              onSelected: (String key) =>
                  ref.read(visibleFloorProvider.notifier).show(key),
              maxLabelWidth: _maxLabelWidth,
            ),
        ],
      ),
    );
  }
}

/// One compact floating chip that either opens a menu or, with a single
/// option, simply states the current value.
class _MapChoice<T> extends StatelessWidget {
  const _MapChoice({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.semanticLabel,
    required this.value,
    required this.options,
    required this.onSelected,
    required this.maxLabelWidth,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final String semanticLabel;
  final T value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onSelected;
  final double maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final bool interactive = options.length > 1;

    final Widget body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: AppSizes.iconSmall),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // The affordance is a shape, not a colour: no chevron means there
            // is nothing to open.
            if (interactive) ...<Widget>[
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.arrow_drop_down, size: AppSizes.iconSmall),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: interactive,
      readOnly: !interactive,
      excludeSemantics: true,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: interactive
            ? PopupMenuButton<T>(
                tooltip: tooltip,
                initialValue: value,
                onSelected: onSelected,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<T>>[
                  for (final ({T value, String label}) option in options)
                    PopupMenuItem<T>(
                      value: option.value,
                      child: Text(option.label),
                    ),
                ],
                child: body,
              )
            : body,
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.bottom, required this.onPressed});

  final double bottom;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      end: AppSpacing.lg,
      bottom: bottom,
      child: FloatingActionButton.small(
        heroTag: 'campus-map-reset',
        tooltip: context.l10n.campusMapResetZoom,
        onPressed: onPressed,
        child: const Icon(Icons.zoom_out_map),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.meeting_room_outlined),
      title: Text(room.primaryLabel),
      subtitle: Text(
        '${room.roomNumber} · ${roomTypeLabel(context, room.roomType)} · '
        '${room.floorName}',
      ),
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
