import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/models/invitation_model.dart';

void main() {
  test('Expected Month event is save-the-date only, not RSVP-ready', () {
    final event = WeddingEventInvitationOption(
      id: 'event-expected',
      weddingId: 'w1',
      name: 'Tiệc cưới dự kiến',
      expectedYear: 2026,
      expectedMonth: 12,
      lifecycleStatus: 'ACTIVE',
    );

    expect(event.isActive, isTrue);
    expect(event.isSaveTheDateOnly, isTrue);
    expect(event.isRsvpReady, isFalse);
    expect(event.readinessLabel, contains('Save-the-date'));
  });

  test('Exact Date event is RSVP-ready without time or venue', () {
    final event = WeddingEventInvitationOption(
      id: 'event-exact',
      weddingId: 'w1',
      name: 'Lễ cưới',
      exactDate: DateTime(2026, 12, 18),
      lifecycleStatus: 'ACTIVE',
    );

    expect(event.isRsvpReady, isTrue);
    expect(event.readinessLabel, contains('RSVP-ready'));
  });

  test('Removed event is not selectable for invitation targeting', () {
    final event = WeddingEventInvitationOption(
      id: 'event-removed',
      weddingId: 'w1',
      name: 'Lễ đã xóa',
      exactDate: DateTime(2026, 12, 18),
      lifecycleStatus: 'REMOVED',
    );

    expect(event.isActive, isFalse);
    expect(event.isRsvpReady, isFalse);
    expect(event.readinessLabel, contains('Đã xóa'));
  });

  test('Invitation lifecycle helpers allow only approved forward actions', () {
    final draft = _invitation(status: InvitationStatus.draft);
    final ready = _invitation(status: InvitationStatus.ready);
    final sent = _invitation(status: InvitationStatus.markedAsSent);

    expect(InvitationStatus.canMoveToReady(draft), isTrue);
    expect(InvitationStatus.canMoveToReady(ready), isFalse);
    expect(InvitationStatus.canMarkAsSent(ready), isTrue);
    expect(InvitationStatus.canMarkAsSent(sent), isFalse);
  });

  test(
    'Credential result uses fragment link and stores no local token cache',
    () {
      final result = InvitationCredentialResult.fromJson({
        'invitation_id': 'inv-1',
        'credential_id': 'cred-1',
        'raw_token': 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
        'link_fragment': '#/invite/ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijk012345',
      });

      expect(result.sharePath, startsWith('#/invite/'));
      expect(result.sharePath, isNot(contains('?token=')));
      expect(result.rawToken, hasLength(43));
    },
  );
}

InvitationModel _invitation({required String status}) {
  final now = DateTime(2026, 8, 24);
  return InvitationModel(
    id: 'inv-$status',
    weddingId: 'w1',
    invitationPartyId: 'p1',
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}
