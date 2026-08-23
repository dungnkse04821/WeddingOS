import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class EventRemovalPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  const EventRemovalPreviewScreen({super.key, required this.event});

  @override
  State<EventRemovalPreviewScreen> createState() =>
      _EventRemovalPreviewScreenState();
}

class _EventRemovalPreviewScreenState extends State<EventRemovalPreviewScreen> {
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _previewData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final data = await SupabaseService.instance.previewEventRemoval(
        eventId: widget.event['id'] as String,
      );

      setState(() {
        _previewData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _commitRemoval() async {
    if (_previewData == null) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final fingerprint = _previewData!['impact_fingerprint'] as String;
      final result = await SupabaseService.instance.commitEventRemoval(
        eventId: widget.event['id'] as String,
        impactFingerprint: fingerprint,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hủy sự kiện thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      setState(() {
        _submitting = false;
      });

      final errStr = e.toString();
      if (errStr.contains('STALE_IMPACT') || errStr.contains('40001')) {
        _showStaleImpactDialog();
      } else {
        setState(() {
          _errorMessage = errStr;
        });
      }
    }
  }

  void _showStaleImpactDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'Dữ liệu đã thay đổi',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'Không gian lập kế hoạch đã được chỉnh sửa kể từ khi bạn mở xem trước này. Vui lòng tải lại xem trước để kiểm tra lại tác động trước khi lưu.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _loadPreview();
              },
              child: const Text(
                'Tải lại xem trước',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final blockingInvariants = _previewData != null
        ? List<String>.from(_previewData!['blocking_invariants'] ?? [])
        : <String>[];
    final bool isBlocked = blockingInvariants.contains(
      'FINAL_MAIN_EVENT_INVARIANT',
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Xem trước hủy sự kiện',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.pinkAccent),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Event warning banner
                    if (isBlocked) _buildBlockingWarningBanner(),

                    // Event details card
                    _buildEventDetailsCard(),
                    const SizedBox(height: 20),

                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_previewData != null && !isBlocked) ...[
                      // Dynamic budgets & targetings card
                      _buildDownstreamSummaryCard(),
                      const SizedBox(height: 16),

                      // Deletion Candidates List
                      _buildDeletionCandidatesSection(),
                      const SizedBox(height: 16),

                      // Preservation Tasks List
                      _buildPreservationTasksSection(),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
      bottomNavigationBar: isBlocked ? null : _buildBottomActions(),
    );
  }

  Widget _buildBlockingWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không thể hủy sự kiện',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Lễ cưới bắt buộc phải có ít nhất một sự kiện chính (Main Event) hoạt động. Vui lòng chọn hoặc tạo một sự kiện chính khác trước khi hủy sự kiện này.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event['name'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                widget.event['is_main_event'] == true
                    ? 'Sự kiện chính (Main Event)'
                    : 'Sự kiện phụ',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownstreamSummaryCard() {
    final budgets = _previewData!['budget_items_count'] as int? ?? 0;
    final invitations = _previewData!['invitations_count'] as int? ?? 0;

    if (budgets == 0 && invitations == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ảnh hưởng tài chính & lời mời',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Divider(color: Colors.white10, height: 20),
          if (budgets > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.orangeAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$budgets mục ngân sách sẽ được gỡ liên kết sự kiện.',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          if (invitations > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.mail_outline_rounded,
                    color: Colors.blueAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$invitations lời mời/nhóm khách có sự kiện này (vẫn được giữ lại, sự kiện sẽ không khả dụng sau khi xóa).',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Deletion candidates section — read-only, server-authoritative.
  /// The server determines which tasks are candidates for deletion
  /// (untouched active SYSTEM_TEMPLATE/RECOMMENDATION tasks). The client
  /// cannot override this classification.
  Widget _buildDeletionCandidatesSection() {
    final candidates = List<dynamic>.from(
      _previewData!['deletion_candidates'] ?? [],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Công việc mẫu sẽ xóa',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Các đầu việc hệ thống mẫu chưa chỉnh sửa dưới đây sẽ được tự động xóa. Phân loại này do hệ thống quyết định.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Divider(color: Colors.white10, height: 20),
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Không có công việc mẫu nào bị xóa.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            ...candidates.map((task) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task['name'] as String,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreservationTasksSection() {
    final list = List<dynamic>.from(_previewData!['preservation_tasks'] ?? []);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Công việc tự chọn được giữ lại',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Đây là các đầu việc do bạn tạo, hoặc đã hoàn thành, hoặc đã chỉnh sửa. Chúng sẽ được dời lên mức chung của Đám cưới và cập nhật hạn chót:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Divider(color: Colors.white10, height: 20),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Không có công việc nào được dời đi.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            ...list.map((task) {
              final newIntent = task['new_deadline_intent'] as String;
              final newDeadline = task['new_resolved_deadline_at'] as String?;
              final String status = task['status'] as String;

              String badgeText = '';
              Color badgeColor = Colors.grey;

              if (status == 'COMPLETED') {
                badgeText = 'ĐÃ XONG (Giữ hạn)';
                badgeColor = Colors.green;
              } else if (newIntent == 'USER_ABSOLUTE') {
                badgeText = 'ĐỔI SANG TUYỆT ĐỐI (${newDeadline ?? ''})';
                badgeColor = Colors.orangeAccent;
              } else if (newIntent == 'NO_DEADLINE') {
                badgeText = 'GỠ HẠN CHỐT (Cần duyệt)';
                badgeColor = Colors.redAccent;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['name'] as String,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        border: Border.all(color: badgeColor.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white10),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: const Text(
                  'Quay lại',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (_previewData == null || _submitting || _loading)
                    ? null
                    : _commitRemoval,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Hủy sự kiện',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
