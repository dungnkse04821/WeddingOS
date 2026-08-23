import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class PartyMovePreviewScreen extends StatefulWidget {
  final String guestId;
  final String guestName;
  final String? targetPartyId;
  final String? targetPartyName;

  const PartyMovePreviewScreen({
    super.key,
    required this.guestId,
    required this.guestName,
    required this.targetPartyId,
    required this.targetPartyName,
  });

  @override
  State<PartyMovePreviewScreen> createState() => _PartyMovePreviewScreenState();
}

class _PartyMovePreviewScreenState extends State<PartyMovePreviewScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _sourcePartyName;
  int _sourceInvitedCount = 0;
  int _targetInvitedCount = 0;
  String _impactFingerprint = '';

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
      final data = await SupabaseService.instance.previewGuestPartyMove(widget.guestId, widget.targetPartyId);
      setState(() {
        _sourcePartyName = data['source_party_name'] as String?;
        _sourceInvitedCount = data['source_invited_count'] as int;
        _targetInvitedCount = data['target_invited_count'] as int;
        _impactFingerprint = data['impact_fingerprint'] as String;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải thông tin xem trước: $e';
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
      await SupabaseService.instance.commitGuestPartyMove(widget.guestId, widget.targetPartyId, _impactFingerprint);
      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('STALE_IMPACT') || errStr.contains('40001')) {
        _showStaleImpactDialog();
      } else {
        setState(() {
          _errorMessage = 'Lỗi di chuyển nhóm mời: $e';
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
        title: const Text('Dữ liệu đã thay đổi', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Thông số nhóm mời nguồn/đích hoặc số chỗ ngồi đã thay đổi kể từ khi xem trước. Vui lòng tải lại thông tin xem trước mới nhất.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _loadPreview();
            },
            child: const Text('Tải lại Preview', style: TextStyle(color: Color(0xFF00C6FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRemove = widget.targetPartyId == null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(isRemove ? 'Xem trước gỡ khỏi nhóm' : 'Xem trước di chuyển nhóm', style: const TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C6FF)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
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
                        'XÁC NHẬN LUỒNG DI CHUYỂN / GỠ KHÁCH',
                        style: TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hành động: Di chuyển khách mời "${widget.guestName}"',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow('Nhóm mời hiện tại:', _sourcePartyName ?? 'Khách lẻ độc lập (Unassigned)'),
                            if (_sourcePartyName != null)
                              _buildSubInfoRow('Số người mời (chỗ ngồi) của nhóm cũ:', '$_sourceInvitedCount (Không đổi)'),
                            const Divider(color: Colors.white10, height: 24),
                            _buildInfoRow('Nhóm mời mới:', widget.targetPartyName ?? 'Khách lẻ độc lập (Unassigned)'),
                            if (widget.targetPartyId != null)
                              _buildSubInfoRow('Số người mời (chỗ ngồi) của nhóm mới:', '$_targetInvitedCount (Không đổi)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Quy tắc nghiệp vụ áp dụng:',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const BulletPoint2(text: 'Hạn mức chỗ ngồi (Invited Count) của cả hai nhóm mời cũ và mới sẽ được giữ nguyên tuyệt đối.'),
                      const BulletPoint2(text: 'Khách mời không làm ảnh hưởng hay thay đổi cấu trúc RSVP, thiệp mời đã chuẩn bị/gửi của nhóm.'),
                      const BulletPoint2(text: 'Liên kết thiệp mời và RSVP thuộc về Nhóm mời (InvitationParty) chứ không thuộc về Khách lẻ.'),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Hủy', style: TextStyle(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C6FF),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _handleCommit,
                              child: const Text('Xác nhận lưu', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        Expanded(
          flex: 6,
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSubInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Text(label, style: const TextStyle(color: Colors.white30, fontSize: 11)),
          ),
          Expanded(
            flex: 4,
            child: Text(value, style: const TextStyle(color: Color(0xFF00C6FF), fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class BulletPoint2 extends StatelessWidget {
  final String text;
  const BulletPoint2({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF00C6FF), fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}
