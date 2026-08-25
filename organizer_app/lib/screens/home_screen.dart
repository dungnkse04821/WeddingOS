import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/task_model.dart';
import 'auth_screen.dart';
import 'wedding_selection_screen.dart';
import 'planning_screen.dart';
import 'directory_screen.dart';
import 'vietqr_configuration_screen.dart';
import 'cover_media_screen.dart';
import 'wedding_lifecycle_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  Map<String, dynamic>? _wedding;
  List<Map<String, dynamic>> _members = [];
  List<TaskModel> _tasks = [];
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
          .maybeSingle();

      if (wResponse == null) {
        await SupabaseService.instance.clearSelectedWedding();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WeddingSelectionScreen()),
            (route) => false,
          );
        }
        return;
      }

      // 2. Fetch wedding members via RLS SELECT on public.wedding_members
      final mResponse = await SupabaseService.instance.client
          .from('wedding_members')
          .select('id, user_id, display_name, profile_email, role, status')
          .order('created_at', ascending: true);

      // 3. Fetch tasks to compute progress metrics
      List<TaskModel> taskList = [];
      if (wResponse['initial_plan_generated_at'] != null) {
        taskList = await SupabaseService.instance.fetchTasks(selectedId);
      }

      setState(() {
        _wedding = wResponse;
        _members = List<Map<String, dynamic>>.from(mResponse);
        _tasks = taskList;
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
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5E7E).withOpacity(0.06),
                    blurRadius: 120,
                    spreadRadius: 150,
                  ),
                ],
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
    final currentUserId = SupabaseService.instance.currentUser?.id;
    final isOwner = _members.any(
      (member) => member['user_id'] == currentUserId &&
          member['status'] == 'ACTIVE' &&
          member['role'] == 'OWNER',
    );

    if (status == 'DELETING') {
      return WeddingLifecyclePanel(
        weddingId: _wedding!['id'] as String,
        weddingName: _wedding!['name'] as String,
        status: status,
        isOwner: isOwner,
        onArchived: () {},
        onDeleted: _handleDeleted,
        onSwitchWedding: _switchWedding,
      );
    }

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

          WeddingLifecyclePanel(
            weddingId: _wedding!['id'] as String,
            weddingName: _wedding!['name'] as String,
            status: status,
            isOwner: isOwner,
            onArchived: () => setState(() => _wedding!['status'] = 'ARCHIVED'),
            onDeleted: _handleDeleted,
            onSwitchWedding: _switchWedding,
          ),
          const SizedBox(height: 20),

          // Planning progress card
          if (status == 'ACTIVE') ...[
            _buildPlanningProgressCard(context),
            const SizedBox(height: 20),

            // Guest Directory card
            _buildGuestDirectoryCard(context),
            const SizedBox(height: 20),

            _buildVietQrCard(context),
            const SizedBox(height: 20),

            _buildCoverMediaCard(context),
            const SizedBox(height: 20),
          ],

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

  Widget _buildVietQrCard(BuildContext context) {
    if (_wedding == null) return const SizedBox.shrink();
    final enabled = _wedding!['vietqr_enabled'] as bool? ?? false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('VIETQR MỪNG CƯỚI', style: TextStyle(color: Color(0xFFFFC857), fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Text(enabled ? 'Đang bật có điều kiện' : 'Chưa bật', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Chỉ hiện trên thiệp sau khi RSVP hiện tại đã hoàn tất.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => VietQrConfigurationScreen(wedding: _wedding!),
              ));
              if (changed == true) _loadWorkspaceData();
            },
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Cấu hình VietQR'),
          ),
        ],
      ),
    );
  }

  void _switchWedding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WeddingSelectionScreen()),
    );
  }

  Future<void> _handleDeleted() async {
    await SupabaseService.instance.clearSelectedWedding();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WeddingSelectionScreen()),
      (route) => false,
    );
  }

  Widget _buildCoverMediaCard(BuildContext context) {
    final archived = _wedding!['status'] == 'ARCHIVED';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('INVITATION COVER PHOTO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(archived ? 'Archived: existing cover is read-only.' : 'Upload one optimized WebP cover for your guest invitation.', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CoverMediaScreen(wedding: _wedding!))), icon: const Icon(Icons.image_outlined), label: const Text('Manage Cover Photo')),
      ]),
    );
  }

  Widget _buildPlanningProgressCard(BuildContext context) {
    if (_wedding == null) return const SizedBox.shrink();

    final isGenerated = _wedding!['initial_plan_generated_at'] != null;

    final activeTasks = _tasks.where((t) => t.status != 'CANCELLED').toList();
    final completedTasks = activeTasks.where((t) => t.status == 'COMPLETED').toList();
    
    final total = activeTasks.length;
    final completed = completedTasks.length;
    final progress = total > 0 ? (completed / total * 100).round() : 0;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B4EFF).withOpacity(0.12),
            const Color(0xFFFF5E7E).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: Color(0xFFFF5E7E), size: 22),
              const SizedBox(width: 10),
              Text(
                'WEDDING PREPARATION PROGRESS',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (isGenerated)
                Text(
                  '$progress%',
                  style: const TextStyle(
                    color: Color(0xFFFF5E7E),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isGenerated) ...[
            Text(
              'No Roadmap Configured',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Generate a customized preparation roadmap based on your cultural preferences to kickstart planning.',
              style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlanningScreen(weddingId: _wedding!['id'] as String)),
                );
                _loadWorkspaceData();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Generate Preparation Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Text(
                  '$completed of $total steps completed',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: total > 0 ? (completed / total) : 0.0,
                backgroundColor: Colors.white10,
                color: const Color(0xFFFF5E7E),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF).withOpacity(0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: const Color(0xFF6B4EFF).withOpacity(0.4)),
                ),
                minimumSize: const Size(double.infinity, 48),
                elevation: 0,
              ),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlanningScreen(weddingId: _wedding!['id'] as String)),
                );
                _loadWorkspaceData();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Open Planning Checklist', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestDirectoryCard(BuildContext context) {
    if (_wedding == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B4EFF).withOpacity(0.08),
            const Color(0xFF00C6FF).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: Color(0xFF00C6FF), size: 22),
              const SizedBox(width: 10),
              Text(
                'GUEST DIRECTORY',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Manage primary relationship groups, invitation parties, individual guest list, and track RSVP seat allocation.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C6FF).withOpacity(0.2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: const Color(0xFF00C6FF).withOpacity(0.4)),
              ),
              minimumSize: const Size(double.infinity, 48),
              elevation: 0,
            ),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DirectoryScreen(weddingId: _wedding!['id'] as String)),
              );
              _loadWorkspaceData();
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_shared_rounded, size: 16),
                SizedBox(width: 8),
                Text('Open Guest Directory', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
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
