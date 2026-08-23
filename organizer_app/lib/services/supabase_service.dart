import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../foundation/constants.dart';
import '../models/task_model.dart';
import '../models/primary_group_model.dart';
import '../models/invitation_party_model.dart';
import '../models/guest_model.dart';
import '../models/guest_import_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  bool _initialized = false;
  late final SharedPreferences _prefs;

  static const String _prefSelectedWeddingId = 'selected_wedding_id';
  static const String _prefSelectedWeddingName = 'selected_wedding_name';

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;

  Session? get currentSession => client.auth.currentSession;

  bool get isAuthenticated => currentUser != null;

  Future<void> initialize() async {
    if (_initialized) return;

    await Supabase.initialize(
      url: Constants.supabaseUrl,
      anonKey: Constants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Performs OAuth Google Sign-In and exchanges credentials for a Supabase session.
  /// Follows the Native Google Sign-In -> signInWithIdToken contract (both tokens required).
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // Web OAuth flow
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kDebugMode ? 'http://localhost:3000' : null,
      );
      return;
    }

    // Native Google Sign-In (iOS/Android)
    final googleSignIn = GoogleSignIn.instance;
    final googleUser = await googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('Failed to obtain Google authentication ID token');
    }

    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  /// Developer / Offline test Sign-In using email password (bypasses Google Console setup locally)
  Future<void> signInWithMockEmail(String email, String password) async {
    try {
      await client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      // If mock user doesn't exist, sign up dynamically for offline testing
      if (e.statusCode == '400' ||
          e.message.contains('Invalid login credentials')) {
        await client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': email.split('@').first.toUpperCase()},
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
    await clearSelectedWedding();
  }

  /// Calls api_v1.create_wedding (TOP-WED-001) RPC with a client-generated request_id.
  Future<Map<String, dynamic>> createWedding({
    required String requestId,
    required String name,
    required String culturalContext,
    DateTime? exactDate,
    int? expectedYear,
    int? expectedMonth,
    double? targetBudget,
  }) async {
    final response = await client.rpc(
      'create_wedding',
      params: {
        'p_request_id': requestId,
        'p_name': name,
        'p_cultural_context': culturalContext,
        'p_exact_date': exactDate?.toIso8601String().split('T').first,
        'p_expected_year': expectedYear,
        'p_expected_month': expectedMonth,
        'p_target_budget': targetBudget,
      },
    );

    // Parse the JSONB response
    final data = response as Map<String, dynamic>;
    final wedding = data['wedding'] as Map<String, dynamic>;

    // Save selection locally
    await saveSelectedWedding(
      wedding['id'] as String,
      wedding['name'] as String,
    );

    return data;
  }

  /// Gets the currently selected wedding workspace (if any) from local storage
  String? getSelectedWeddingId() {
    return _prefs.getString(_prefSelectedWeddingId);
  }

  String? getSelectedWeddingName() {
    return _prefs.getString(_prefSelectedWeddingName);
  }

  Future<void> saveSelectedWedding(String id, String name) async {
    await _prefs.setString(_prefSelectedWeddingId, id);
    await _prefs.setString(_prefSelectedWeddingName, name);
  }

  Future<void> clearSelectedWedding() async {
    await _prefs.remove(_prefSelectedWeddingId);
    await _prefs.remove(_prefSelectedWeddingName);
  }

  /// Queries the active weddings for the current user using RLS SELECT on public.weddings
  Future<List<Map<String, dynamic>>> fetchMyWeddings() async {
    try {
      final data = await client
          .from('weddings')
          .select(
            'id, name, target_budget, exact_date, expected_year, expected_month, status, initial_plan_generated_at',
          )
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      if (kDebugMode) print('Error fetching weddings: $e');
      return [];
    }
  }

  /// Calls api_v1.generate_initial_plan RPC to build default cultural template tasks.
  Future<Map<String, dynamic>> generateInitialPlan(String weddingId) async {
    final response = await client.rpc(
      'generate_initial_plan',
      params: {'p_wedding_id': weddingId},
    );
    return response as Map<String, dynamic>;
  }

  /// Fetches all active tasks for the selected wedding workspace.
  Future<List<TaskModel>> fetchTasks(String weddingId) async {
    try {
      final data = await client
          .from('tasks')
          .select('*')
          .eq('wedding_id', weddingId)
          .order('created_at', ascending: true);

      return (data as List)
          .map((json) => TaskModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching tasks: $e');
      rethrow;
    }
  }

  /// Directly updates a task's status under Class-B rules.
  /// Trigger logic handles timestamping/freeze/overrides.
  Future<void> updateTaskStatus(String taskId, String status) async {
    await client.from('tasks').update({'status': status}).eq('id', taskId);
  }

  /// Directly creates a new USER task under Class-B rules.
  Future<void> createCustomTask({
    required String weddingId,
    required String name,
    required String deadlineIntent,
    int? dateOffset,
    DateTime? customOverrideDate,
    String? weddingEventId,
    String side = 'COMMON',
  }) async {
    await client.from('tasks').insert({
      'wedding_id': weddingId,
      'name': name,
      'deadline_intent': deadlineIntent,
      'date_offset': dateOffset,
      'custom_override_date': customOverrideDate
          ?.toIso8601String()
          .split('T')
          .first,
      'wedding_event_id': weddingEventId,
      'side': side,
    });
  }

  /// Fetches all active events of a wedding.
  Future<List<Map<String, dynamic>>> fetchWeddingEvents(
    String weddingId,
  ) async {
    final data = await client
        .from('wedding_events')
        .select('*')
        .eq('wedding_id', weddingId)
        .eq('lifecycle_status', 'ACTIVE')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Creates a Main Event for the wedding workspace.
  Future<void> createMainEvent({
    required String weddingId,
    required String name,
    DateTime? exactDate,
    int? expectedYear,
    int? expectedMonth,
  }) async {
    await client.from('wedding_events').insert({
      'wedding_id': weddingId,
      'name': name,
      'exact_date': exactDate?.toIso8601String().split('T').first,
      'expected_year': expectedYear,
      'expected_month': expectedMonth,
      'is_main_event': true,
      'lifecycle_status': 'ACTIVE',
    });
  }

  /// Preview event date change impact (TOP-EVT-002)
  Future<Map<String, dynamic>> previewEventDateChange({
    required String eventId,
    DateTime? targetExactDate,
    int? targetExpectedYear,
    int? targetExpectedMonth,
  }) async {
    final response = await client.rpc(
      'preview_event_date_change',
      params: {
        'p_event_id': eventId,
        'p_target_exact_date': targetExactDate
            ?.toIso8601String()
            .split('T')
            .first,
        'p_target_expected_year': targetExpectedYear,
        'p_target_expected_month': targetExpectedMonth,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Commit event date change (TOP-EVT-002)
  /// IMPL-CONFLICT-004: p_batch_action_c removed. USER_ABSOLUTE tasks are
  /// calendar-fixed and are never adjusted by event date transitions.
  Future<Map<String, dynamic>> commitEventDateChange({
    required String eventId,
    DateTime? targetExactDate,
    int? targetExpectedYear,
    int? targetExpectedMonth,
    required String impactFingerprint,
  }) async {
    final response = await client.rpc(
      'commit_event_date_change',
      params: {
        'p_event_id': eventId,
        'p_target_exact_date': targetExactDate
            ?.toIso8601String()
            .split('T')
            .first,
        'p_target_expected_year': targetExpectedYear,
        'p_target_expected_month': targetExpectedMonth,
        'p_impact_fingerprint': impactFingerprint,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Preview event removal impact (TOP-EVT-003)
  Future<Map<String, dynamic>> previewEventRemoval({
    required String eventId,
  }) async {
    final response = await client.rpc(
      'preview_event_removal',
      params: {'p_event_id': eventId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// Commit event removal (TOP-EVT-003)
  /// IMPL-CONFLICT-005: p_explicit_choices removed. Task classification
  /// (deletion vs preservation) is server-authoritative and not overridable
  /// by the client. The server deletes all untouched active SYSTEM_TEMPLATE/
  /// RECOMMENDATION tasks and preserves all user-created/modified/completed tasks.
  Future<Map<String, dynamic>> commitEventRemoval({
    required String eventId,
    required String impactFingerprint,
  }) async {
    final response = await client.rpc(
      'commit_event_removal',
      params: {
        'p_event_id': eventId,
        'p_impact_fingerprint': impactFingerprint,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  // ===========================================================================
  // M2B.1 GUEST FOUNDATION SERVICES
  // ===========================================================================

  /// Fetch all relationship groups for a wedding
  Future<List<PrimaryGroupModel>> fetchPrimaryGroups(String weddingId) async {
    try {
      final data = await client
          .from('primary_groups')
          .select('*')
          .eq('wedding_id', weddingId)
          .order('name', ascending: true);
      return (data as List)
          .map(
            (json) => PrimaryGroupModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching groups: $e');
      rethrow;
    }
  }

  /// Create a primary group
  Future<void> createPrimaryGroup(String weddingId, String name) async {
    await client.from('primary_groups').insert({
      'wedding_id': weddingId,
      'name': name,
    });
  }

  /// Update a primary group name
  Future<void> updatePrimaryGroup(String groupId, String name) async {
    await client
        .from('primary_groups')
        .update({'name': name})
        .eq('id', groupId);
  }

  /// Fetch all invitation parties for a wedding
  Future<List<InvitationPartyModel>> fetchInvitationParties(
    String weddingId,
  ) async {
    try {
      final data = await client
          .from('invitation_parties')
          .select('*')
          .eq('wedding_id', weddingId)
          .order('display_name', ascending: true);
      return (data as List)
          .map(
            (json) =>
                InvitationPartyModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching parties: $e');
      rethrow;
    }
  }

  /// Create an invitation party
  Future<void> createInvitationParty({
    required String weddingId,
    required String displayName,
    required int invitedCount,
  }) async {
    await client.from('invitation_parties').insert({
      'wedding_id': weddingId,
      'display_name': displayName,
      'invited_count': invitedCount,
    });
  }

  /// Update an invitation party
  Future<void> updateInvitationParty({
    required String partyId,
    required String displayName,
    required int invitedCount,
  }) async {
    await client
        .from('invitation_parties')
        .update({'display_name': displayName, 'invited_count': invitedCount})
        .eq('id', partyId);
  }

  /// Fetch all guests for a wedding
  Future<List<GuestModel>> fetchGuests(String weddingId) async {
    try {
      final data = await client
          .from('guests')
          .select('*')
          .eq('wedding_id', weddingId)
          .order('name', ascending: true);
      return (data as List)
          .map((json) => GuestModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching guests: $e');
      rethrow;
    }
  }

  /// Create a guest record
  Future<void> createGuest(GuestModel guest) async {
    await client.from('guests').insert(guest.toJson());
  }

  /// Update a guest record
  Future<void> updateGuest(GuestModel guest) async {
    await client.from('guests').update(guest.toJson()).eq('id', guest.id);
  }

  /// Check duplicate warnings for a guest using a safe read query on the RLS-isolated table
  Future<List<Map<String, dynamic>>> checkGuestDuplicates({
    required String weddingId,
    required String name,
    String? phone,
    String? email,
  }) async {
    // 1. Normalize parameters on client side
    String? normPhone;
    if (phone != null && phone.trim().isNotEmpty) {
      normPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (normPhone.startsWith('84')) {
        normPhone = '0' + normPhone.substring(2);
      }
    }

    String? normEmail;
    if (email != null && email.trim().isNotEmpty) {
      normEmail = email.trim().toLowerCase();
    }

    final trimmedName = name.trim().toLowerCase();

    // 2. Query all guests for this wedding (automatically scoped by RLS)
    final data = await client
        .from('guests')
        .select('id, name, phone, email, normalized_phone, normalized_email')
        .eq('wedding_id', weddingId);

    final List<Map<String, dynamic>> results = [];
    for (final row in (data as List)) {
      final rowName = (row['name'] as String).trim().toLowerCase();
      final rowNormPhone = row['normalized_phone'] as String?;
      final rowNormEmail = row['normalized_email'] as String?;

      bool isMatch = false;
      String reason = 'UNKNOWN';

      if (normPhone != null && rowNormPhone == normPhone) {
        isMatch = true;
        reason = 'TRUNG_SO_DIEN_THOAI';
      } else if (normEmail != null && rowNormEmail == normEmail) {
        isMatch = true;
        reason = 'TRUNG_EMAIL';
      } else if (trimmedName.isNotEmpty && rowName == trimmedName) {
        isMatch = true;
        reason = 'TRUNG_TEN';
      }

      if (isMatch) {
        results.add({
          'id': row['id'],
          'name': row['name'],
          'phone': row['phone'],
          'email': row['email'],
          'match_reason': reason,
        });
      }
    }
    return results;
  }

  /// Preview relationship group deletion (TOP-GUE-001)
  Future<Map<String, dynamic>> previewPrimaryGroupDelete(String groupId) async {
    final response = await client.rpc(
      'preview_primary_group_delete',
      params: {'p_group_id': groupId},
    );
    return response as Map<String, dynamic>;
  }

  /// Commit relationship group deletion (TOP-GUE-001)
  Future<Map<String, dynamic>> commitPrimaryGroupDelete(
    String groupId,
    String fingerprint,
  ) async {
    final response = await client.rpc(
      'commit_primary_group_delete',
      params: {'p_group_id': groupId, 'p_impact_fingerprint': fingerprint},
    );
    return response as Map<String, dynamic>;
  }

  /// Preview guest party move/remove (TOP-GUE-002)
  Future<Map<String, dynamic>> previewGuestPartyMove(
    String guestId,
    String? targetPartyId,
  ) async {
    final response = await client.rpc(
      'preview_guest_party_move',
      params: {'p_guest_id': guestId, 'p_target_party_id': targetPartyId},
    );
    return response as Map<String, dynamic>;
  }

  /// Commit guest party move/remove (TOP-GUE-002)
  Future<Map<String, dynamic>> commitGuestPartyMove(
    String guestId,
    String? targetPartyId,
    String fingerprint,
  ) async {
    final response = await client.rpc(
      'commit_guest_party_move',
      params: {
        'p_guest_id': guestId,
        'p_target_party_id': targetPartyId,
        'p_impact_fingerprint': fingerprint,
      },
    );
    return response as Map<String, dynamic>;
  }

  /// Preview guest duplicate merge (TOP-GUE-003)
  Future<Map<String, dynamic>> previewGuestMerge(
    String guestId1,
    String guestId2,
  ) async {
    final response = await client.rpc(
      'preview_guest_merge',
      params: {'p_guest_id_1': guestId1, 'p_guest_id_2': guestId2},
    );
    return response as Map<String, dynamic>;
  }

  /// Commit guest duplicate merge (TOP-GUE-003)
  Future<Map<String, dynamic>> commitGuestMerge({
    required String survivorId,
    required String secondaryId,
    required String resolvedName,
    String? resolvedPhone,
    String? resolvedEmail,
    required String resolvedSide,
    required String resolvedSource,
    String? resolvedGroupId,
    String? resolvedPartyId,
    required String fingerprint,
  }) async {
    final response = await client.rpc(
      'commit_guest_merge',
      params: {
        'p_survivor_guest_id': survivorId,
        'p_secondary_guest_id': secondaryId,
        'p_resolved_name': resolvedName,
        'p_resolved_phone': resolvedPhone,
        'p_resolved_email': resolvedEmail,
        'p_resolved_side': resolvedSide,
        'p_resolved_guest_source': resolvedSource,
        'p_resolved_primary_group_id': resolvedGroupId,
        'p_resolved_invitation_party_id': resolvedPartyId,
        'p_impact_fingerprint': fingerprint,
      },
    );
    return response as Map<String, dynamic>;
  }

  /// Confirm locally parsed Excel Guest Import rows (TOP-GUE-004).
  Future<GuestImportConfirmResult> confirmGuestImport({
    required String requestId,
    required String weddingId,
    required List<Map<String, dynamic>> rows,
  }) async {
    final response = await client.rpc(
      'confirm_guest_import',
      params: {
        'p_request_id': requestId,
        'p_wedding_id': weddingId,
        'p_rows': rows,
      },
    );
    return GuestImportConfirmResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
