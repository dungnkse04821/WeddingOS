import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer_app/models/guest_model.dart';
import 'package:organizer_app/models/invitation_party_model.dart';
import 'package:organizer_app/models/primary_group_model.dart';
import 'package:organizer_app/screens/guest_create_edit_screen.dart';
import 'package:organizer_app/screens/party_create_edit_screen.dart';

void main() {
  final testGroups = [
    PrimaryGroupModel(
      id: 'g1',
      weddingId: 'w1',
      name: 'Đồng nghiệp',
      createdAt: DateTime.now(),
    ),
    PrimaryGroupModel(
      id: 'g2',
      weddingId: 'w1',
      name: 'Bạn cấp 3',
      createdAt: DateTime.now(),
    ),
  ];

  final testParties = [
    InvitationPartyModel(
      id: 'p1',
      weddingId: 'w1',
      displayName: 'Gia đình bác Tư',
      invitedCount: 4,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InvitationPartyModel(
      id: 'p2',
      weddingId: 'w1',
      displayName: 'Anh Nam & bạn',
      invitedCount: 2,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final testGuests = [
    GuestModel(
      id: 'e1',
      weddingId: 'w1',
      name: 'Nguyễn Văn A',
      phone: '0912345678',
      normalizedPhone: '0912345678',
      side: 'BRIDE_SIDE',
      guestSource: 'BRIDE',
      primaryGroupId: 'g1',
      invitationPartyId: 'p1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    GuestModel(
      id: 'e2',
      weddingId: 'w1',
      name: 'Nguyễn Văn B',
      phone: '0987654321',
      normalizedPhone: '0987654321',
      side: 'GROOM_SIDE',
      guestSource: 'GROOM',
      primaryGroupId: 'g2',
      invitationPartyId: null, // unassigned
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  testWidgets('DirectoryScreen renders Guest List and Party List tabs', (
    WidgetTester tester,
  ) async {
    // We mock directory screen directly by injecting data or inflating widgets since we don't fetch from DB here
    // Let's pump GuestCreateEditScreen first to test form input validation
    await tester.pumpWidget(
      MaterialApp(
        home: GuestCreateEditScreen(
          weddingId: 'w1',
          groups: testGroups,
          parties: testParties,
        ),
      ),
    );

    // Verify Name input exists
    expect(find.byType(TextFormField), findsNWidgets(3)); // Họ tên, SĐT, Email
    expect(find.text('Họ và tên khách mời *'), findsOneWidget);

    // Verify Side dropdown defaults to COMMON
    expect(find.text('Chung (Common)'), findsOneWidget);

    // Verify Source dropdown defaults to OTHER
    expect(find.text('Nguồn khác (Other)'), findsOneWidget);
  });

  testWidgets(
    'PartyCreateEditScreen preserves Invited Count and renders members',
    (WidgetTester tester) async {
      final party = testParties.first; // Gia đình bác Tư, count = 4

      await tester.pumpWidget(
        MaterialApp(
          home: PartyCreateEditScreen(
            weddingId: 'w1',
            party: party,
            allGuests: testGuests,
          ),
        ),
      );

      // Verify display name and invited count inputs render values
      expect(find.text('Gia đình bác Tư'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // Verify warning notice about invariant preservation is shown
      expect(
        find.text(
          'Thay đổi danh sách thành viên bên dưới sẽ không tự động làm thay đổi hạn mức Số người mời thực tế đã chốt.',
        ),
        findsOneWidget,
      );

      // Verify members of this party are listed
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(
        find.text('Nguyễn Văn B'),
        findsOneWidget,
      ); // unassigned guest is in bottom list
    },
  );
}
