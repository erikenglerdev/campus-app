// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../data/map_asset_loader.dart';
import '../data/rooms_repository.dart';
import '../domain/map_catalog.dart';
import '../domain/room.dart';

/// The room catalogue from the Campus API, cached for offline use.
final FutureProvider<Loaded<List<Room>>> roomsProvider =
    FutureProvider<Loaded<List<Room>>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      return ref.watch(roomsRepositoryProvider).fetchRooms(locale: locale);
    });

/// Overridable so tests can supply a bundle without touching the asset system.
final Provider<MapAssetLoader> mapAssetLoaderProvider =
    Provider<MapAssetLoader>((Ref ref) => const MapAssetLoader());

/// The bundled geometry. Local, locale independent and read exactly once.
final FutureProvider<MapCatalog> mapCatalogProvider =
    FutureProvider<MapCatalog>(
      (Ref ref) => ref.watch(mapAssetLoaderProvider).load(),
    );

/// The room the map should focus, set by search or by a contact deep link.
final NotifierProvider<SelectedRoomController, String?> selectedRoomProvider =
    NotifierProvider<SelectedRoomController, String?>(
      SelectedRoomController.new,
    );

class SelectedRoomController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String roomKey) => state = roomKey;

  /// Back to the overview. Reachable from a clearly visible action.
  void clear() => state = null;
}

/// The floor currently shown. Follows the selection but can be changed freely.
final NotifierProvider<VisibleFloorController, String?> visibleFloorProvider =
    NotifierProvider<VisibleFloorController, String?>(
      VisibleFloorController.new,
    );

class VisibleFloorController extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String floorKey) => state = floorKey;
}
