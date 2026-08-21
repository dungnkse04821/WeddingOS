import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../foundation/constants.dart';
import '../models/task_model.dart';

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
      if (e.statusCode == '400' || e.message.contains('Invalid login credentials')) {
        await client.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': email.split('@').first.toUpperCase(),
          },
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
          .select('id, name, target_budget, exact_date, expected_year, expected_month, status, initial_plan_generated_at')
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
      params: {
        'p_wedding_id': weddingId,
      },
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
      
      return (data as List).map((json) => TaskModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching tasks: $e');
      rethrow;
    }
  }

  /// Directly updates a task's status under Class-B rules.
  /// Trigger logic handles timestamping/freeze/overrides.
  Future<void> updateTaskStatus(String taskId, String status) async {
    await client
        .from('tasks')
        .update({
          'status': status,
        })
        .eq('id', taskId);
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
      'custom_override_date': customOverrideDate?.toIso8601String().split('T').first,
      'wedding_event_id': weddingEventId,
      'side': side,
    });
  }

  /// Fetches all active events of a wedding.
  Future<List<Map<String, dynamic>>> fetchWeddingEvents(String weddingId) async {
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
}
