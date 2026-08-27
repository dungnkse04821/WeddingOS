import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/services/create_wedding_draft.dart';
import 'package:organizer_app/services/session_recovery.dart';

void main() {
  group('central session state', () {
    test('valid and lost sessions produce deterministic state', () {
      final controller = SessionRecoveryController();
      expect(controller.status, AppSessionStatus.initializing);
      controller.markAuthenticated();
      expect(controller.status, AppSessionStatus.authenticated);
      controller.markAuthLost();
      expect(controller.status, AppSessionStatus.authLost);
    });

    test('token refresh requests access revalidation without logout', () {
      final controller = SessionRecoveryController();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.markAuthenticated();
      final afterSignIn = notifications;
      controller.markAuthenticated(revalidate: true);

      expect(controller.status, AppSessionStatus.authenticated);
      expect(notifications, afterSignIn + 1);
    });
  });

  group('selected Wedding revalidation', () {
    test(
      'keeps ACTIVE, ARCHIVED, and OWNER DELETING metadata accessible',
      () async {
        for (final status in ['ACTIVE', 'ARCHIVED', 'DELETING']) {
          var saved = '';
          final result = await resolveSelectedWeddingAccess(
            selectedWeddingId: 'w-a',
            fetchWeddings: () async => [
              {'id': 'w-a', 'name': 'Wedding A', 'status': status},
            ],
            clearSelection: () async => fail('must not clear'),
            saveSelection: (id, name) async => saved = '$id:$name',
          );
          expect(result.destination, WeddingAccessDestination.home);
          expect(result.wedding?['status'], status);
          expect(saved, 'w-a:Wedding A');
        }
      },
    );

    test(
      'clears revoked, deleted, or collaborator-DELETING selection',
      () async {
        var cleared = false;
        final result = await resolveSelectedWeddingAccess(
          selectedWeddingId: 'stale-wedding',
          fetchWeddings: () async => [
            {
              'id': 'other-wedding',
              'name': 'Other Wedding',
              'status': 'ACTIVE',
            },
          ],
          clearSelection: () async => cleared = true,
          saveSelection: (_, __) async => fail('must not save stale selection'),
        );

        expect(cleared, isTrue);
        expect(result.destination, WeddingAccessDestination.selection);
      },
    );

    test('recovers to no-Wedding selection when no access remains', () async {
      var cleared = false;
      final result = await resolveSelectedWeddingAccess(
        selectedWeddingId: 'deleted-wedding',
        fetchWeddings: () async => [],
        clearSelection: () async => cleared = true,
        saveSelection: (_, __) async {},
      );
      expect(cleared, isTrue);
      expect(result.destination, WeddingAccessDestination.selection);
    });
  });

  test('in-memory draft preserves only declared non-sensitive form fields', () {
    CreateWeddingDraftStore.instance.save(
      const CreateWeddingDraft(
        name: 'An & Bình',
        targetBudget: '1000000.01',
        culturalContext: 'VIETNAMESE',
      ),
    );

    final draft = CreateWeddingDraftStore.instance.draft!;
    expect(draft.name, 'An & Bình');
    expect(draft.targetBudget, '1000000.01');
    expect(draft.toString(), isNot(contains('token')));
    CreateWeddingDraftStore.instance.clear();
    expect(CreateWeddingDraftStore.instance.draft, isNull);
  });
}
