import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class GroupDeletePreviewScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDeletePreviewScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDeletePreviewScreen> createState() =>
      _GroupDeletePreviewScreenState();
}

class _GroupDeletePreviewScreenState extends State<GroupDeletePreviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _affectedGuestCount = 0;
  List<dynamic> _affectedGuests = [];
  String _impactFingerprint = '';

  String _safeErrorMessage(Object error, String fallback) {
    final text = error.toString();
    if (text.contains('42501') || text.contains('Unauthorized')) {
      return 'Bạn không có quyền thực hiện thao tác này hoặc đám cưới không còn ở trạng thái cho phép chỉnh sửa.';
    }
    if (text.contains('44000') || text.contains('not found')) {
      return 'Dữ liệu liên quan không còn tồn tại. Vui lòng tải lại danh sách mới nhất.';
    }
    if (text.contains('40009') || text.contains('CONFLICT')) {
      return 'Không thể hoàn tất thao tác vì trạng thái dữ liệu hiện tại cần được rà soát lại.';
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await SupabaseService.instance.previewPrimaryGroupDelete(
        widget.groupId,
      );
      setState(() {
        _affectedGuestCount = data['affected_guest_count'] as int;
        _affectedGuests = data['affected_guests'] as List<dynamic>;
        _impactFingerprint = data['impact_fingerprint'] as String;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = _safeErrorMessage(
          e,
          'Không thể tải thông tin xem trước. Vui lòng thử lại.',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCommit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.instance.commitPrimaryGroupDelete(
        widget.groupId,
        _impactFingerprint,
      );
      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('STALE_IMPACT') || errStr.contains('40001')) {
        _showStaleImpactDialog();
      } else {
        setState(() {
          _errorMessage = _safeErrorMessage(
            e,
            'Không thể xóa nhóm vào lúc này. Vui lòng tải lại và thử lại.',
          );
          _isLoading = false;
        });
      }
    }
  }

  void _showStaleImpactDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Dữ liệu đã thay đổi',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Thông tin nhóm hoặc số lượng khách mời liên kết đã thay đổi kể từ khi xem trước. Vui lòng tải lại thông tin xem trước mới nhất.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _loadPreview();
            },
            child: const Text(
              'Tải lại Preview',
              style: TextStyle(color: Color(0xFF00C6FF)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Xác nhận xóa nhóm',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00C6FF)),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadPreview,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CẢNH BÁO TÁC ĐỘNG XÓA NHÓM',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bạn đang chuẩn bị xóa nhóm quan hệ "${widget.groupName}".',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Các quy tắc an toàn hệ thống:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const BulletPoint(
                    text: 'Khách mời thuộc nhóm này sẽ KHÔNG bị xóa khỏi đám cưới.',
                  ),
                  const BulletPoint(
                    text: 'Mối quan hệ nhóm của họ sẽ chuyển thành "Chưa gán nhóm" (PrimaryGroup = NONE).',
                  ),
                  const BulletPoint(
                    text: 'Tác vụ này không thay đổi thành viên nhóm mời hay số người mời (Invited Count).',
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Số lượng khách mời ảnh hưởng: $_affectedGuestCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (_affectedGuests.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Danh sách khách mời bị ảnh hưởng:',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _affectedGuests.length,
                              itemBuilder: (context, index) {
                                final guest = _affectedGuests[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Text(
                                    '- ${guest['name']}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _handleCommit,
                          child: const Text(
                            'Xác nhận xóa',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;
  const BulletPoint({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.amber, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
