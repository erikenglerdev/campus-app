// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../domain/map_catalog.dart';

/// The zoomable floor plan.
///
/// The SVG is a bundled, generated asset — never anything fetched or
/// manipulated at runtime. The selection highlight is drawn as an overlay in
/// plan coordinates rather than by editing the SVG, which keeps the asset
/// immutable and the highlight themable.
///
/// The highlight deliberately uses THREE cues, not just colour: a thick
/// outline, a marker above the room, and a textual statement of the selection
/// outside the map (see [CampusMapScreen]).
class FloorMapView extends StatefulWidget {
  const FloorMapView({required this.floor, required this.selected, super.key});

  final MapFloor floor;
  final MapRoomGeometry? selected;

  @override
  State<FloorMapView> createState() => FloorMapViewState();
}

class FloorMapViewState extends State<FloorMapView> {
  final TransformationController _controller = TransformationController();

  /// Scale factor from plan units to laid-out pixels; set by the layout pass.
  double _planScale = 1;
  Size _viewport = Size.zero;

  @override
  void didUpdateWidget(FloorMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected?.roomKey != widget.selected?.roomKey ||
        oldWidget.floor.floorKey != widget.floor.floorKey) {
      // Focus after layout so the viewport size is known.
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusSelection());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scale from plan units to laid-out pixels. Exposed for the focus test.
  @visibleForTesting
  double get planScale => _planScale;

  /// The transform currently applied to the plan. Exposed for the focus test.
  @visibleForTesting
  Matrix4 get currentTransform => _controller.value;

  /// Where the plan's top-left corner sits inside the viewport.
  ///
  /// The plan is laid out inside a [Center], so whenever it does not fill the
  /// viewport it is offset — and focusing in plain plan coordinates would then
  /// land next to the intended room instead of on it.
  Offset get _planOrigin {
    final Rect viewBox = widget.floor.viewBox;
    final Size planSize = Size(
      viewBox.width * _planScale,
      viewBox.height * _planScale,
    );
    return Offset(
      math.max(0, (_viewport.width - planSize.width) / 2),
      math.max(0, (_viewport.height - planSize.height) / 2),
    );
  }

  /// Brings the selected room into a comfortable part of the viewport.
  void _focusSelection() {
    if (!mounted || _viewport.isEmpty) return;
    final MapRoomGeometry? room = widget.selected;
    if (room == null) {
      resetView();
      return;
    }

    final Rect bounds = room.bounds;
    // Leave room around the shape so the highlight is not glued to the edge.
    const double padding = 1.6;
    final double fit = math.min(
      _viewport.width / (bounds.width * _planScale * padding),
      _viewport.height / (bounds.height * _planScale * padding),
    );
    final double scale = fit.clamp(1.0, 6.0);

    // The room's focus point expressed in the InteractiveViewer's CHILD
    // coordinates, i.e. including the centring offset.
    final Offset centre =
        _planOrigin +
        Offset(room.focus.dx * _planScale, room.focus.dy * _planScale);

    setState(() {
      _controller.value = Matrix4.identity()
        ..translateByDouble(
          _viewport.width / 2 - centre.dx * scale,
          _viewport.height / 2 - centre.dy * scale,
          0,
          1,
        )
        ..scaleByDouble(scale, scale, 1, 1);
    });
  }

  /// Back to the whole floor.
  void resetView() {
    if (!mounted) return;
    setState(() => _controller.value = Matrix4.identity());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Rect viewBox = widget.floor.viewBox;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = math.min(
          constraints.maxWidth / viewBox.width,
          constraints.maxHeight / viewBox.height,
        );
        final Size planSize = Size(
          viewBox.width * scale,
          viewBox.height * scale,
        );

        // Remembered for focusing; the callback runs outside the build phase.
        if (_planScale != scale || _viewport != constraints.biggest) {
          _planScale = scale;
          _viewport = constraints.biggest;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.selected != null) _focusSelection();
          });
        }

        return Semantics(
          label: l10n.campusMapSemanticMap,
          child: ClipRect(
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 1,
              maxScale: 8,
              child: Center(
                child: SizedBox(
                  width: planSize.width,
                  height: planSize.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      SvgPicture.asset(
                        widget.floor.svgAsset,
                        fit: BoxFit.fill,
                        // The plan is decorative here; the textual room details
                        // outside the map carry the information.
                        excludeFromSemantics: true,
                      ),
                      if (widget.selected != null)
                        CustomPaint(
                          painter: _SelectionPainter(
                            room: widget.selected!,
                            planScale: scale,
                            color: Theme.of(context).colorScheme.primary,
                            onColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the selection highlight in plan coordinates.
class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({
    required this.room,
    required this.planScale,
    required this.color,
    required this.onColor,
  });

  final MapRoomGeometry room;
  final double planScale;
  final Color color;

  /// Contrast colour for the marker centre; comes from the theme so the
  /// highlight stays legible in both light and dark mode.
  final Color onColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(
      room.bounds.left * planScale,
      room.bounds.top * planScale,
      room.bounds.width * planScale,
      room.bounds.height * planScale,
    );
    final RRect rounded = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(AppRadius.sm),
    );

    // A translucent wash makes the room readable without hiding its label…
    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.22),
    );
    // …and a heavy outline carries the state without relying on colour alone.
    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );

    // A marker above the room: a third, shape-based cue.
    final Offset tip = Offset(rect.center.dx, rect.top);
    final Path marker = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 9, tip.dy - 14)
      ..lineTo(tip.dx + 9, tip.dy - 14)
      ..close();
    canvas.drawPath(marker, Paint()..color = color);
    canvas.drawCircle(Offset(tip.dx, tip.dy - 20), 9, Paint()..color = color);
    canvas.drawCircle(Offset(tip.dx, tip.dy - 20), 4, Paint()..color = onColor);
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) =>
      oldDelegate.room.roomKey != room.roomKey ||
      oldDelegate.planScale != planScale ||
      oldDelegate.color != color ||
      oldDelegate.onColor != onColor;
}
