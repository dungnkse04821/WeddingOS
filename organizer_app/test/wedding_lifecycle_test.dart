import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/screens/wedding_lifecycle_panel.dart';
import 'package:organizer_app/services/wedding_lifecycle_service.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

WeddingLifecyclePanel _panel({
  String status = 'ACTIVE',
  bool isOwner = true,
  WeddingLifecycleService? service,
  VoidCallback? onArchived,
  Future<void> Function()? onDeleted,
  VoidCallback? onSwitch,
}) => WeddingLifecyclePanel(
  weddingId: 'wedding-a',
  weddingName: 'Đám Cưới An & Bình',
  status: status,
  isOwner: isOwner,
  service: service,
  onArchived: onArchived ?? () {},
  onDeleted: onDeleted ?? () async {},
  onSwitchWedding: onSwitch ?? () {},
);

void main() {
  group('typed Wedding-name confirmation', () {
    test('trims, ignores case, and normalizes Unicode', () {
      expect(
        weddingNamesMatch(
          'Đám Cưới An & Bình',
          '  đa\u0301m cưới an & bình  ',
        ),
        isTrue,
      );
    });

    test('preserves Vietnamese diacritic distinctions', () {
      expect(
        weddingNamesMatch('Đám Cưới An & Bình', 'Dam Cuoi An & Binh'),
        isFalse,
      );
    });
  });

  testWidgets('collaborator sees no lifecycle controls', (tester) async {
    await tester.pumpWidget(_app(_panel(isOwner: false)));
    expect(find.byKey(const Key('archive-action')), findsNothing);
    expect(find.byKey(const Key('delete-action')), findsNothing);
  });

  testWidgets('archive cancellation makes no call and confirmation archives', (
    tester,
  ) async {
    var calls = 0;
    var archived = false;
    final service = WeddingLifecycleService(
      rpcInvoker: (functionName, params) async {
        expect(functionName, 'archive_wedding');
        expect(params, {'p_wedding_id': 'wedding-a'});
        calls++;
      },
    );
    await tester.pumpWidget(
      _app(_panel(service: service, onArchived: () => archived = true)),
    );

    await tester.tap(find.byKey(const Key('archive-action')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dữ liệu vẫn được giữ lại'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(calls, 0);

    await tester.tap(find.byKey(const Key('archive-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-archive')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(archived, isTrue);
  });

  testWidgets('archived state is read-only with no archive or unarchive', (
    tester,
  ) async {
    var switched = false;
    await tester.pumpWidget(
      _app(_panel(status: 'ARCHIVED', onSwitch: () => switched = true)),
    );
    expect(find.byKey(const Key('archived-badge')), findsOneWidget);
    expect(find.byKey(const Key('archive-action')), findsNothing);
    expect(find.byKey(const Key('delete-action')), findsOneWidget);
    expect(find.textContaining('khôi phục'), findsNothing);
    await tester.tap(find.byKey(const Key('switch-archived-wedding')));
    expect(switched, isTrue);
  });

  testWidgets('delete stays disabled until normalized name matches', (
    tester,
  ) async {
    var deleted = false;
    var requestedId = '';
    final service = WeddingLifecycleService(
      edgeInvoker: (functionName, body) async {
        expect(functionName, 'wedding-delete');
        expect(body.keys, ['wedding_id']);
        requestedId = body['wedding_id'] as String;
        return {'status': 'DELETED'};
      },
    );
    await tester.pumpWidget(
      _app(
        _panel(
          service: service,
          onDeleted: () async => deleted = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('delete-action')));
    await tester.pumpAndSettle();
    final deleteButton = find.byKey(const Key('confirm-delete'));
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNull);
    await tester.enterText(
      find.byKey(const Key('delete-name-input')),
      '  đa\u0301m cưới an & bình  ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(deleteButton).onPressed, isNotNull);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(requestedId, 'wedding-a');
    expect(deleted, isTrue);
  });

  testWidgets('typed confirmation is discarded when dialog closes', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_panel()));
    await tester.tap(find.byKey(const Key('delete-action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delete-name-input')),
      'Đám Cưới An & Bình',
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-action')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('delete-name-input'))).controller?.text ?? '', isEmpty);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('confirm-delete'))).onPressed,
      isNull,
    );
  });

  testWidgets('DELETING is recovery-only and successful retry clears state', (
    tester,
  ) async {
    var retries = 0;
    var deleted = false;
    var switched = false;
    final service = WeddingLifecycleService(
      edgeInvoker: (_, __) async {
        retries++;
        return {'status': 'DELETED'};
      },
    );
    await tester.pumpWidget(
      _app(
        _panel(
          status: 'DELETING',
          service: service,
          onDeleted: () async => deleted = true,
          onSwitch: () => switched = true,
        ),
      ),
    );
    expect(find.byKey(const Key('deleting-state')), findsOneWidget);
    expect(find.byKey(const Key('archive-action')), findsNothing);
    expect(find.byKey(const Key('delete-action')), findsNothing);
    await tester.tap(find.byKey(const Key('retry-delete')));
    await tester.pump();
    await tester.pump();
    expect(retries, 1);
    expect(deleted, isTrue);
    await tester.tap(find.byKey(const Key('switch-wedding')));
    expect(switched, isTrue);
  });

  testWidgets('retry-required result remains bounded and retryable', (
    tester,
  ) async {
    var calls = 0;
    final service = WeddingLifecycleService(
      edgeInvoker: (_, __) async {
        calls++;
        return {'status': 'DELETING'};
      },
    );
    await tester.pumpWidget(
      _app(_panel(status: 'DELETING', service: service)),
    );
    await tester.tap(find.byKey(const Key('retry-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Quá trình xóa chưa hoàn tất. Bạn có thể thử lại.'), findsWidgets);
    await tester.tap(find.byKey(const Key('retry-delete')));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('archived owner may enter permanent-delete flow', (tester) async {
    await tester.pumpWidget(_app(_panel(status: 'ARCHIVED')));
    await tester.tap(find.byKey(const Key('delete-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete-name-input')), findsOneWidget);
  });
}
