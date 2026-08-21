import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'auth_screen.dart';
import 'wedding_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  Map<String, dynamic>? _wedding;
  List<Map<String, dynamic>> _members = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWorkspaceData();
  }

  Future<void> _loadWorkspaceData() async {
    final selectedId = SupabaseService.instance.getSelectedWeddingId();
    if (selectedId == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WeddingSelectionScreen()),
        );
      }
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch wedding details via RLS SELECT on public.weddings
      final wResponse = await SupabaseService.instance.client
          .from('weddings')
          .select()
          .eq('id', selectedId)
          .single();

      // 2. Fetch wedding members via RLS SELECT on public.wedding_members
      final mResponse = await SupabaseService.instance.client
          .from('wedding_members')
          .select('id, display_name, profile_email, role, status')
          .order('created_at', ascending: true);

      setState(() {
        _wedding = wResponse;
        _members = List<Map<String, dynamic>>.from(mResponse);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load workspace: $e';
        _loading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    await SupabaseService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weddingName = SupabaseService.instance.getSelectedWeddingName() ?? 'Wedding Workspace';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: Text(
          weddingName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white70),
            tooltip: 'Switch Workspace',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const WeddingSelectionScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Sign Out',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF5E7E).withOpacity(0.06),
                blurRadius: 120,
              ),
            ),
          ),

          _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6B4EFF),
                  ),
                )
              : _errorMessage != null
                  ? _buildErrorState()
                  : _buildDashboard(theme),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF),
                foregroundColor: Colors.white,
              ),
              onPressed: _loadWorkspaceData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(ThemeData theme) {
    if (_wedding == null) return const SizedBox.shrink();

    final targetBudget = _wedding!['target_budget'] != null 
        ? '${_wedding!['target_budget']} VND'
        : 'Not set';
    
    String dateStr = 'Not set';
    if (_wedding!['exact_date'] != null) {
      dateStr = _wedding!['exact_date'] as String;
    } else if (_wedding!['expected_year'] != null && _wedding!['expected_month'] != null) {
      dateStr = 'Expected: ${_wedding!['expected_month']}/${_wedding!['expected_year']}';
    }

    final timezone = _wedding!['timezone'] as String? ?? 'Asia/Ho_Chi_Minh';
    final culturalContext = _wedding!['cultural_context'] as String? ?? 'TUY_CHON';
    final status = _wedding!['status'] as String? ?? 'ACTIVE';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection status chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_rounded, color: Colors.greenAccent, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Tenant Isolated (RLS ACTIVE)',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Workspace overview card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'FOUNDATION METADATA',
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _buildMetadataRow('Wedding ID', _wedding!['id'] as String, isCopyable: true),
                const Divider(color: Colors.white10),
                _buildMetadataRow('Status', status, color: Colors.greenAccent),
                const Divider(color: Colors.white10),
                _buildMetadataRow('Cultural Context', culturalContext),
                const Divider(color: Colors.white10),
                _buildMetadataRow('Wedding Date', dateStr),
                const Divider(color: Colors.white10),
                _buildMetadataRow('Target Budget', targetBudget),
                const Divider(color: Colors.white10),
                _buildMetadataRow('Timezone', timezone),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Members list section
          Text(
            'Workspace Members (${_members.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final m = _members[index];
              final displayName = m['display_name'] as String? ?? 'Unknown';
              final email = m['profile_email'] as String? ?? '';
              final role = m['role'] as String? ?? 'COLLABORATOR';
              final isOwner = role == 'OWNER';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isOwner ? const Color(0xFFFF5E7E) : const Color(0xFF6B4EFF),
                      radius: 20,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isOwner ? const Color(0xFFFF5E7E) : const Color(0xFF6B4EFF)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: isOwner ? const Color(0xFFFF5E7E) : const Color(0xFF6B4EFF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value, {bool isCopyable = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.bold,
                overflow: TextOverflow.ellipsis,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          if (isCopyable) ...[
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 14, color: Colors.white38),
          ],
        ],
      ),
    );
  }
}
