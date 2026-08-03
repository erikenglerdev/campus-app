// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/requests/application/requests_controller.dart';
import 'package:campus_koethen/features/requests/data/attachment_picker.dart';
import 'package:campus_koethen/features/requests/domain/request_models.dart';
import 'package:campus_koethen/features/requests/domain/request_store.dart';
import 'package:campus_koethen/features/requests/presentation/request_draft_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

/// A picker that never opens a platform dialog.
class _FakePicker implements AttachmentPicker {
  _FakePicker(this._next);

  final List<RequestAttachment> _next;
  final List<RequestAttachment> discarded = <RequestAttachment>[];
  int pickCalls = 0;

  @override
  Future<List<RequestAttachment>> pick() async {
    pickCalls++;
    return _next;
  }

  @override
  Future<void> discard(RequestAttachment attachment) async =>
      discarded.add(attachment);
}

const RequestAttachment _file = RequestAttachment(
  fileName: 'kostenplan.pdf',
  path: '/documents/request_attachments/1-kostenplan.pdf',
  sizeBytes: 2048,
);

Future<void> pumpEditor(
  WidgetTester tester, {
  required AttachmentPicker picker,
  RequestStore? store,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpScreen(
    tester,
    const RequestDraftScreen(
      draftId: 'new',
      kind: RequestKind.financeApplication,
    ),
    locale: locale,
    overrides: <Override>[
      requestStoreProvider.overrideWithValue(store ?? InMemoryRequestStore()),
      attachmentPickerProvider.overrideWithValue(picker),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty draft says it has no attachments', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester, picker: _FakePicker(const <RequestAttachment>[]));
    expect(find.text('Keine Anhänge.'), findsOneWidget);
  });

  testWidgets('a picked file is listed with its size', (
    WidgetTester tester,
  ) async {
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[_file]),
    );

    await tester.tap(find.text('Datei hinzufügen'));
    await tester.pumpAndSettle();

    expect(find.text('kostenplan.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    expect(find.text('Keine Anhänge.'), findsNothing);
  });

  testWidgets('a picked file is persisted immediately', (
    WidgetTester tester,
  ) async {
    // The copy already exists on disk; losing the reference to it would leave
    // an orphaned file behind.
    final InMemoryRequestStore store = InMemoryRequestStore();
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[_file]),
      store: store,
    );

    await tester.tap(find.text('Datei hinzufügen'));
    await tester.pumpAndSettle();

    final List<RequestDraft> saved = await store.readDrafts();
    expect(saved, hasLength(1));
    expect(saved.single.attachments, contains(_file));
  });

  testWidgets('cancelling the picker changes nothing', (
    WidgetTester tester,
  ) async {
    final _FakePicker picker = _FakePicker(const <RequestAttachment>[]);
    final InMemoryRequestStore store = InMemoryRequestStore();
    await pumpEditor(tester, picker: picker, store: store);

    await tester.tap(find.text('Datei hinzufügen'));
    await tester.pumpAndSettle();

    expect(picker.pickCalls, 1);
    expect(find.text('Keine Anhänge.'), findsOneWidget);
    expect(await store.readDrafts(), isEmpty);
  });

  testWidgets('removing an attachment also discards the copy', (
    WidgetTester tester,
  ) async {
    // Otherwise the app would accumulate files nobody can see or delete.
    final _FakePicker picker = _FakePicker(const <RequestAttachment>[_file]);
    await pumpEditor(tester, picker: picker);

    await tester.tap(find.text('Datei hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Anhang entfernen'));
    await tester.pumpAndSettle();

    expect(find.text('kostenplan.pdf'), findsNothing);
    expect(picker.discarded, <RequestAttachment>[_file]);
  });

  testWidgets('attachments survive a round trip through storage', (
    WidgetTester tester,
  ) async {
    final InMemoryRequestStore store = InMemoryRequestStore();
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[_file]),
      store: store,
    );
    await tester.tap(find.text('Datei hinzufügen'));
    await tester.pumpAndSettle();

    final RequestDraft stored = (await store.readDrafts()).single;
    final RequestDraft? reloaded = RequestDraft.fromJson(stored.toJson());
    expect(reloaded?.attachments.single.fileName, 'kostenplan.pdf');
    expect(reloaded?.attachments.single.sizeBytes, 2048);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[]),
      locale: AppLocales.english,
    );
    expect(find.text('Add file'), findsOneWidget);
    expect(find.text('No attachments.'), findsOneWidget);
  });
}
