// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

/// Verifies that the renderer actually understands the generated plan.
///
/// The canonical drawing styles rooms through a `<style>` block with CSS class
/// selectors, which `flutter_svg` does NOT support — it logs "unhandled element
/// <style/>" and drops the whole stylesheet, leaving every room unstyled while
/// every other test still passes. The generator therefore inlines the styles,
/// and this test is what keeps that guarantee honest.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the bundled plan renders without unsupported constructs', (
    WidgetTester tester,
  ) async {
    final List<String> messages = <String>[];
    final DebugPrintCallback original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: SvgPicture.asset('assets/maps/demo-north/level2.svg'),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      debugPrint = original;
    }

    expect(tester.takeException(), isNull);

    final Iterable<String> unhandled = messages.where(
      (String message) => message.contains('unhandled element'),
    );
    expect(
      unhandled,
      isEmpty,
      reason:
          'the generated asset must not contain constructs the renderer drops: '
          '${unhandled.join(', ')}',
    );
  });
}
