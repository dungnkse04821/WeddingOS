import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/models/guest_model.dart';

void main() {
  GuestModel guest(String id) => GuestModel(
    id: id,
    weddingId: 'wedding-id',
    invitationPartyId: 'party-id',
    primaryGroupId: 'group-id',
    name: 'Guest',
    phone: '0912345678',
    normalizedPhone: '0912345678',
    email: 'guest@example.com',
    normalizedEmail: 'guest@example.com',
    side: 'COMMON',
    guestSource: 'OTHER',
    createdAt: DateTime.utc(2026, 8, 29),
    updatedAt: DateTime.utc(2026, 8, 29),
  );

  test('guest writes contain only approved mutable columns', () {
    final payload = guest('').toJson();

    expect(payload.keys, containsAll(<String>[
      'wedding_id',
      'invitation_party_id',
      'primary_group_id',
      'name',
      'phone',
      'email',
      'side',
      'guest_source',
    ]));
    expect(payload.containsKey('id'), isFalse);
    expect(payload.containsKey('normalized_phone'), isFalse);
    expect(payload.containsKey('normalized_email'), isFalse);
    expect(payload.containsKey('created_at'), isFalse);
    expect(payload.containsKey('updated_at'), isFalse);
  });

  test('existing guest identity remains a URL filter concern, not a write field', () {
    expect(guest('guest-id').toJson().containsKey('id'), isFalse);
  });
}
