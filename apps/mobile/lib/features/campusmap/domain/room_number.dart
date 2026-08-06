// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// How a room number is compared, in one place.
///
/// Search, mention resolution and ranking all fold numbers the same way — a
/// second spelling of these rules is a second answer to "is this the same
/// room", and the two would drift apart.
library;

final RegExp _separator = RegExp(r'[^\p{L}\p{N}]', unicode: true);
final RegExp _leadingLetters = RegExp(r'^\p{L}+', unicode: true);

/// Folds a room number or query into a comparable form.
///
/// People write `B.201`, `B 201` and `B201` for the same room, so every
/// separator is removed before comparing. Letters are kept as they are, so
/// umlauts still match.
String normalizeRoomQuery(String input) =>
    input.toLowerCase().replaceAll(_separator, '');

/// A normalised number without its building letters: `b202` → `202`.
///
/// Empty when the value carries no digits at all.
String bareRoomNumber(String normalisedNumber) =>
    normalisedNumber.replaceFirst(_leadingLetters, '');
