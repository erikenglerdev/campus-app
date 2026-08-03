// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import '../../../app/app_sections.dart';

/// The cards the day dashboard can show, in their product-default order.
///
/// The order below is the answer to "what does a student need to know first",
/// not an arbitrary list: what is happening now, then the rest of the day,
/// then food, then what changed, then what is due — and only afterwards the
/// discreet status of the personal services.
enum DashboardCard {
  /// The lecture happening now, or the next one.
  nextClass('next-class'),

  /// The remaining appointments of the day, across all calendar sources.
  todaysAgenda('todays-agenda'),

  /// Today's canteen offer.
  canteen('canteen'),

  /// Unread announcements.
  news('news', isImplemented: false),

  /// Local to-dos and, once Moodle is set up, its upcoming submissions.
  tasks('tasks'),

  /// Whether there is unread mail — a count and an entry point, never a
  /// subject line.
  mailStatus('mail-status', isImplemented: false),

  /// Whether new grades exist — never a grade value.
  gradesStatus('grades-status', isImplemented: false),

  /// Room search, contacts and other one-tap entries.
  quickActions('quick-actions');

  const DashboardCard(this.storageValue, {this.isImplemented = true});

  /// Stable identifier written to local storage, never the enum index.
  final String storageValue;

  /// Whether this card's data source is wired up yet.
  ///
  /// The redesign lands feature by feature, and a card that renders an empty
  /// frame is worse than a card that is not there: it promises information the
  /// app cannot deliver. Rather than leaving such a card in the list and
  /// silently drawing nothing, the dashboard filters on this flag — and a test
  /// asserts that only implemented cards are ever rendered.
  ///
  /// Each flag disappears when its feature lands.
  final bool isImplemented;

  static DashboardCard? fromStorage(String? value) {
    for (final DashboardCard card in DashboardCard.values) {
      if (card.storageValue == value) return card;
    }
    return null;
  }

  /// The personal service this card reports on, or `null` for public content.
  ///
  /// A card with a service only appears once that service is actually set up —
  /// the dashboard must not advertise something the user never configured, and
  /// it must never imply an account exists where none does.
  AppSection? get requiresService => switch (this) {
    DashboardCard.mailStatus => AppSection.mail,
    DashboardCard.gradesStatus => AppSection.grades,
    _ => null,
  };
}

/// Which dashboard cards are shown, and in which order.
///
/// Like the navigation configuration this **repairs** stored input instead of
/// trusting it: a card removed in a later version, a duplicate or a hand-edited
/// preference must not leave the user with an empty or broken dashboard.
/// A newly added card appears for existing users too, because anything the
/// stored order does not mention is appended rather than dropped.
@immutable
class DashboardConfig {
  const DashboardConfig._({required this.order, required this.hidden});

  /// Every card, in display order — including hidden ones, so switching a card
  /// back on restores its position instead of moving it to the end.
  final List<DashboardCard> order;

  /// The cards the user switched off.
  final Set<DashboardCard> hidden;

  static const DashboardConfig defaults = DashboardConfig._(
    order: DashboardCard.values,
    hidden: <DashboardCard>{},
  );

  factory DashboardConfig.of({
    Iterable<DashboardCard>? order,
    Iterable<DashboardCard>? hidden,
  }) {
    final List<DashboardCard> result = <DashboardCard>[];
    for (final DashboardCard card in order ?? const <DashboardCard>[]) {
      if (!result.contains(card)) result.add(card);
    }
    // Anything the stored order does not know about — a card added in a later
    // version — is appended rather than lost.
    for (final DashboardCard card in DashboardCard.values) {
      if (!result.contains(card)) result.add(card);
    }
    return DashboardConfig._(
      order: List<DashboardCard>.unmodifiable(result),
      hidden: Set<DashboardCard>.unmodifiable(
        (hidden ?? const <DashboardCard>[]).toSet(),
      ),
    );
  }

  factory DashboardConfig.fromStorage({
    List<String>? order,
    List<String>? hidden,
  }) {
    if (order == null && hidden == null) return defaults;
    return DashboardConfig.of(
      order: (order ?? const <String>[])
          .map(DashboardCard.fromStorage)
          .whereType<DashboardCard>(),
      hidden: (hidden ?? const <String>[])
          .map(DashboardCard.fromStorage)
          .whereType<DashboardCard>(),
    );
  }

  /// The cards actually rendered, in order.
  ///
  /// Filters out cards whose source is not wired up yet, so the dashboard can
  /// never show an empty frame for a feature that does not exist.
  List<DashboardCard> get visible => order
      .where((DashboardCard c) => c.isImplemented && !hidden.contains(c))
      .toList(growable: false);

  /// Every card the user may reorder or switch off, including the ones that
  /// are not implemented yet — settings show the full, stable list.
  List<DashboardCard> get configurable => order;

  bool isVisible(DashboardCard card) => !hidden.contains(card);

  DashboardConfig withVisibility(DashboardCard card, {required bool visible}) {
    final Set<DashboardCard> next = hidden.toSet();
    if (visible) {
      next.remove(card);
    } else {
      next.add(card);
    }
    return DashboardConfig.of(order: order, hidden: next);
  }

  /// Moves [card] to [newIndex] within the full order.
  DashboardConfig reordered(DashboardCard card, int newIndex) {
    final List<DashboardCard> next = order.toList();
    final int from = next.indexOf(card);
    if (from == -1) return this;
    next.removeAt(from);
    next.insert(newIndex.clamp(0, next.length), card);
    return DashboardConfig.of(order: next, hidden: hidden);
  }

  List<String> orderToStorage() =>
      order.map((DashboardCard c) => c.storageValue).toList(growable: false);

  List<String> hiddenToStorage() =>
      hidden.map((DashboardCard c) => c.storageValue).toList(growable: false);

  @override
  bool operator ==(Object other) =>
      other is DashboardConfig &&
      listEquals(other.order, order) &&
      setEquals(other.hidden, hidden);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(order), Object.hashAll(hidden));
}
