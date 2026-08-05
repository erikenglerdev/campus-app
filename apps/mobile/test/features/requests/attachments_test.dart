// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/requests/application/requests_controller.dart';
import 'package:campus_koethen/features/requests/data/attachment_picker.dart';
import 'package:campus_koethen/features/requests/domain/application_files.dart';
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

const RequestAttachment _pdf = RequestAttachment(
  fileName: 'kostenplan.pdf',
  path: '/documents/request_attachments/1-kostenplan.pdf',
  sizeBytes: 2048,
);

const RequestAttachment _png = RequestAttachment(
  fileName: 'ausweis.png',
  path: '/documents/request_attachments/2-ausweis.png',
  sizeBytes: 4096,
);

const RequestAttachment _huge = RequestAttachment(
  fileName: 'riesig.pdf',
  path: '/documents/request_attachments/3-riesig.pdf',
  sizeBytes: ApplicationFileSlot.maxBytes + 1,
);

Future<void> pumpEditor(
  WidgetTester tester, {
  required AttachmentPicker picker,
  RequestStore? store,
  Locale locale = AppLocales.german,
}) async {
  tester.view.physicalSize = const Size(390, 3200);
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

/// The "choose file" button belonging to one slot.
/// The tile of one slot. Found by key, because a slot label legitimately
/// repeats elsewhere on the screen — "Finanzantrag" is also the form's title.
Finder slotTile(ApplicationFileSlot slot) =>
    find.byKey(ValueKey<String>('slot-${slot.field}'));

/// The "choose file" button belonging to one slot.
Finder chooseFor(ApplicationFileSlot slot) =>
    find.descendant(of: slotTile(slot), matching: find.text('Datei wählen'));

void main() {
  testWidgets('all four slots are offered, mandatory ones marked as such', (
    WidgetTester tester,
  ) async {
    await pumpEditor(tester, picker: _FakePicker(const <RequestAttachment>[]));

    expect(slotTile(ApplicationFileSlot.financeRequest), findsOneWidget);
    expect(find.text('Studierendenausweis'), findsOneWidget);
    expect(find.text('Anlage A'), findsOneWidget);
    expect(find.text('Anlage B'), findsOneWidget);
    // Two mandatory, two optional — stated in words, never by colour alone.
    expect(find.text('Pflicht'), findsNWidgets(2));
    expect(find.text('Optional'), findsNWidgets(2));
  });

  testWidgets('the student card slot states what happens to the document', (
    WidgetTester tester,
  ) async {
    // It is an identity document; saying where it goes is the least the form
    // owes the person uploading it.
    await pumpEditor(tester, picker: _FakePicker(const <RequestAttachment>[]));
    expect(find.textContaining('nur intern verarbeitet'), findsOneWidget);
  });

  testWidgets('a picked PDF lands in the slot it was chosen for', (
    WidgetTester tester,
  ) async {
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[_pdf]),
    );

    await tester.tap(chooseFor(ApplicationFileSlot.financeRequest));
    await tester.pumpAndSettle();

    expect(find.text('kostenplan.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
  });

  testWidgets('it is persisted immediately', (WidgetTester tester) async {
    final InMemoryRequestStore store = InMemoryRequestStore();
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[_pdf]),
      store: store,
    );

    await tester.tap(chooseFor(ApplicationFileSlot.financeRequest));
    await tester.pumpAndSettle();

    final List<RequestDraft> saved = await store.readDrafts();
    expect(saved, hasLength(1));
    expect(saved.single.fileFor(ApplicationFileSlot.financeRequest), _pdf);
  });

  testWidgets('a file the slot does not accept is refused and discarded', (
    WidgetTester tester,
  ) async {
    // The finance request is PDF only. Keeping a PNG here would guarantee a
    // 400 later, and leave a copy on disk that nothing references.
    final _FakePicker picker = _FakePicker(const <RequestAttachment>[_png]);
    final InMemoryRequestStore store = InMemoryRequestStore();
    await pumpEditor(tester, picker: picker, store: store);

    await tester.tap(chooseFor(ApplicationFileSlot.financeRequest));
    await tester.pumpAndSettle();

    expect(find.text('ausweis.png'), findsNothing);
    expect(picker.discarded, <RequestAttachment>[_png]);
    expect(await store.readDrafts(), isEmpty);
  });

  testWidgets('a PNG is accepted for the student card', (
    WidgetTester tester,
  ) async {
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[_png]),
    );

    await tester.tap(chooseFor(ApplicationFileSlot.studentCard));
    await tester.pumpAndSettle();

    expect(find.text('ausweis.png'), findsOneWidget);
  });

  testWidgets('a file over 25 MB is refused', (WidgetTester tester) async {
    final _FakePicker picker = _FakePicker(const <RequestAttachment>[_huge]);
    await pumpEditor(tester, picker: picker);

    await tester.tap(chooseFor(ApplicationFileSlot.financeRequest));
    await tester.pumpAndSettle();

    expect(find.text('riesig.pdf'), findsNothing);
    expect(picker.discarded, <RequestAttachment>[_huge]);
  });

  testWidgets('cancelling the picker changes nothing', (
    WidgetTester tester,
  ) async {
    final _FakePicker picker = _FakePicker(const <RequestAttachment>[]);
    final InMemoryRequestStore store = InMemoryRequestStore();
    await pumpEditor(tester, picker: picker, store: store);

    await tester.tap(chooseFor(ApplicationFileSlot.financeRequest));
    await tester.pumpAndSettle();

    expect(picker.pickCalls, 1);
    expect(await store.readDrafts(), isEmpty);
  });

  testWidgets('removing a file also discards the copy', (
    WidgetTester tester,
  ) async {
    final _FakePicker picker = _FakePicker(const <RequestAttachment>[_pdf]);
    await pumpEditor(tester, picker: picker);

    await tester.tap(chooseFor(ApplicationFileSlot.financeRequest));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Anhang entfernen').first);
    await tester.pumpAndSettle();

    expect(find.text('kostenplan.pdf'), findsNothing);
    expect(picker.discarded, <RequestAttachment>[_pdf]);
  });

  testWidgets('files survive a round trip through storage', (
    WidgetTester tester,
  ) async {
    final InMemoryRequestStore store = InMemoryRequestStore();
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[_pdf]),
      store: store,
    );
    await tester.tap(chooseFor(ApplicationFileSlot.financeRequest));
    await tester.pumpAndSettle();

    final RequestDraft stored = (await store.readDrafts()).single;
    final RequestDraft? reloaded = RequestDraft.fromJson(stored.toJson());
    expect(
      reloaded?.fileFor(ApplicationFileSlot.financeRequest)?.fileName,
      'kostenplan.pdf',
    );
    // And the key survives too, or a retry would file a second application.
    expect(reloaded?.idempotencyKey, stored.idempotencyKey);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await pumpEditor(
      tester,
      picker: _FakePicker(const <RequestAttachment>[]),
      locale: AppLocales.english,
    );
    expect(slotTile(ApplicationFileSlot.financeRequest), findsOneWidget);
    expect(find.text('Student card'), findsOneWidget);
    expect(find.text('Choose file'), findsNWidgets(4));
  });
}
