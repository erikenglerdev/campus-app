// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

/// An injectable time source, so the 24-hour sync policy can be tested with a
/// controllable clock instead of the wall clock.
abstract interface class Clock {
  DateTime now();
}

/// The real clock used in production.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
