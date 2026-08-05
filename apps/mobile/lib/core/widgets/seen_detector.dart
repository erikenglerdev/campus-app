// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter/material.dart';

/// Reports its child as *seen* once it has genuinely been on screen.
///
/// A list builds its items shortly before they scroll into view, so "the widget
/// exists" is not the same as "somebody looked at it". This waits until at
/// least [minFraction] of the child is inside the viewport and stays there for
/// [dwell] — a fast flick past an article therefore does not count as reading
/// it.
///
/// [onSeen] fires **at most once** per instance.
///
/// This is a rendering aid, not telemetry: nothing is recorded, sent or timed
/// beyond the single callback, and the only caller uses it to set a local
/// read marker.
class SeenDetector extends StatefulWidget {
  const SeenDetector({
    required this.child,
    required this.onSeen,
    this.minFraction = 0.55,
    this.dwell = const Duration(seconds: 1),
    super.key,
  });

  final Widget child;
  final VoidCallback onSeen;

  /// How much of the child must be visible. Slightly over half: an article
  /// whose headline alone peeks in has not been read.
  final double minFraction;

  /// How long it must stay that visible.
  final Duration dwell;

  @override
  State<SeenDetector> createState() => _SeenDetectorState();
}

class _SeenDetectorState extends State<SeenDetector> {
  ScrollPosition? _position;
  Timer? _timer;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    // Items already on screen at first paint never produce a scroll event.
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    if (scrollable?.position == _position) return;
    _position?.removeListener(_evaluate);
    _position = scrollable?.position;
    _position?.addListener(_evaluate);
  }

  @override
  void dispose() {
    _position?.removeListener(_evaluate);
    _timer?.cancel();
    super.dispose();
  }

  void _evaluate() {
    if (_reported || !mounted) return;

    final double fraction = _visibleFraction();
    if (fraction < widget.minFraction) {
      // Scrolled away again before the dwell elapsed — it does not count.
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _timer = Timer(widget.dwell, () {
      if (_reported || !mounted) return;
      // Re-checked, because the list may have moved during the wait.
      if (_visibleFraction() < widget.minFraction) {
        _timer = null;
        return;
      }
      _reported = true;
      widget.onSeen();
    });
  }

  /// How much of this widget lies inside the scroll viewport, 0…1.
  double _visibleFraction() {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || object.size.height <= 0) {
      return 0;
    }
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    final RenderObject? viewport = scrollable?.context.findRenderObject();
    if (viewport is! RenderBox) return 0;

    final Offset childTop = object.localToGlobal(Offset.zero);
    final Offset viewportTop = viewport.localToGlobal(Offset.zero);
    final double top = childTop.dy;
    final double bottom = top + object.size.height;
    final double windowTop = viewportTop.dy;
    final double windowBottom = windowTop + viewport.size.height;

    final double visible =
        (bottom < windowBottom ? bottom : windowBottom) -
        (top > windowTop ? top : windowTop);
    if (visible <= 0) return 0;
    return visible / object.size.height;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
