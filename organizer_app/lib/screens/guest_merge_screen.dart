import 'package:flutter/material.dart';
import '../models/guest_model.dart';
import '../models/primary_group_model.dart';
import '../models/invitation_party_model.dart';
import '../services/supabase_service.dart';

class GuestMergeScreen extends StatefulWidget {
  final List<GuestModel> guests;
  final List<PrimaryGroupModel> groups;
  final List<InvitationPartyModel> parties;
  final GuestModel? initialGuest1;
  final GuestModel? initialGuest2;

  const GuestMergeScreen({
    super.key,
    required this.guests,
    required this.groups,
    required this.parties,
    this.initialGuest1,
    this.initialGuest2,
  });

  @override
  State<GuestMergeScreen> createState() => _GuestMergeScreenState();
}

class _GuestMergeScreenState extends State<GuestMergeScreen> {
  GuestModel? _guest1;
  GuestModel? _guest2;
  int _step = 1; // 1: Select, 2: Survivor, 3: Resolve Conflicts, 4: Review & Commit

  bool _isLoadingPreview = false;
  bool _isCommitting = false;
  String? _errorMessage;

  // Conflict state from server preview
  Map<String, dynamic>? _previewData;
  String _impactFingerprint = '';

  // Resolution selections
  GuestModel? _survivor;
  GuestModel? _secondary;

  String? _resolvedName;
  String? _resolvedPhone;
  String? _resolvedEmail;
  String? _resolvedSide;
  String? _resolvedSource;
  String? _resolvedGroupId;
  String? _resolvedPartyId;

  @override
  void initState() {
    super.initState();
    if (widget.initialGuest1 != null && widget.initialGuest2 != null) {
      _guest1 = widget.initialGuest1;
      _guest2 = widget.initialGuest2;
      _step = 2; // skip selection
      _survivor = _guest1; // default survivor
      _secondary = _guest2;
    }
  }

  Future<void> _fetchPreview() async {
    if (_guest1 == null || _guest2 == null) return;
    setState(() {
      _isLoadingPreview = true;
      _errorMessage = null;
    });

    try {
      final data = await SupabaseService.instance.previewGuestMerge(_guest1!.id, _guest2!.id);
      setState(() {
        _previewData = data;
        _impactFingerprint = data['impact_fingerprint'] as String;
        _isLoadingPreview = false;
        _step = 3;

        // Initialize resolutions with survivor's values as default
        _resolvedName = _survivor!.name;
        _resolvedPhone = _survivor!.phone;
        _resolvedEmail = _survivor!.email;
        _resolvedSide = _survivor!.side;
        _resolvedSource = _survivor!.guestSource;
        _resolvedGroupId = _survivor!.primaryGroupId;
        _resolvedPartyId = _survivor!.invitationPartyId;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi tải xem trước gộp khách: $e';
        _isLoadingPreview = false;
      });
    }
  }

  Future<void> _handleCommit() async {
    setState(() {
      _isCommitting = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.instance.commitGuestMerge(
        survivorId: _survivor!.id,
        secondaryId: _secondary!.id,
        resolvedName: _resolvedName!,
        resolvedPhone: _resolvedPhone,
        resolvedEmail: _resolvedEmail,
        resolvedSide: _resolvedSide!,
        resolvedSource: _resolvedSource!,
        resolvedGroupId: _resolvedGroupId,
        resolvedPartyId: _resolvedPartyId,
        fingerprint: _impactFingerprint,
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
          _errorMessage = 'Lỗi thực thi gộp khách: $e';
          _isCommitting = false;
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
          'Thông tin của một trong hai khách mời đã thay đổi kể từ khi tạo xem trước. Vui lòng tải lại xem trước mới.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _fetchPreview();
            },
            child: const Text('Tải lại Preview', style: TextStyle(color: Color(0xFF00C6FF))),
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
        title: Text('Gộp khách mời trùng lặp (Bước $_step/4)', style: const TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: _isCommitting || _isLoadingPreview
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C6FF)))
          : Column(
              children: [
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.redAccent.withOpacity(0.15),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildStepContent(),
                  ),
                ),
                _buildNavigationButtons(),
              ],
            ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _buildStep1SelectGuests();
      case 2:
        return _buildStep2ChooseSurvivor();
      case 3:
        return _buildStep3ResolveConflicts();
      case 4:
        return _buildStep4ReviewCommit();
      default:
        return Container();
    }
  }

  Widget _buildStep1SelectGuests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHỌN HAI KHÁCH MỜI CẦN GỘP',
          style: TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 16),
        _buildGuestSelector('Khách mời thứ nhất:', _guest1, (val) => setState(() => _guest1 = val)),
        const SizedBox(height: 24),
        _buildGuestSelector('Khách mời thứ hai:', _guest2, (val) => setState(() => _guest2 = val)),
      ],
    );
  }

  Widget _buildGuestSelector(String label, GuestModel? selected, ValueChanged<GuestModel?> onChanged) {
    // Filter out already selected guest
    final list = widget.guests.where((g) {
      if (selected == null) {
        return _guest1?.id != g.id && _guest2?.id != g.id;
      }
      return (_guest1?.id != g.id || _guest1?.id == selected.id) &&
             (_guest2?.id != g.id || _guest2?.id == selected.id);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<GuestModel?>(
              value: selected,
              dropdownColor: const Color(0xFF1E293B),
              hint: const Text('Chọn khách mời', style: TextStyle(color: Colors.white30, fontSize: 14)),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              isExpanded: true,
              onChanged: onChanged,
              items: list.map((g) => DropdownMenuItem(value: g, child: Text('${g.name} (${g.phone ?? "Không có SĐT"})'))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2ChooseSurvivor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CHỌN KHÁCH MỜI SỐNG SÓT (SURVIVOR)',
          style: TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hồ sơ của người được chọn sẽ làm hồ sơ gốc lưu lại. Người còn lại sẽ bị xóa sau khi gộp thành công.',
          style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        _buildSurvivorOption(_guest1!, _guest2!),
        const SizedBox(height: 16),
        _buildSurvivorOption(_guest2!, _guest1!),
      ],
    );
  }

  Widget _buildSurvivorOption(GuestModel candidate, GuestModel other) {
    final isSelected = _survivor?.id == candidate.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _survivor = candidate;
          _secondary = other;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C6FF).withOpacity(0.05) : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C6FF).withOpacity(0.4) : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: candidate.id,
              groupValue: _survivor?.id,
              activeColor: const Color(0xFF00C6FF),
              onChanged: (val) {
                setState(() {
                  _survivor = candidate;
                  _secondary = other;
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    'SĐT: ${candidate.phone ?? "Trống"} | Email: ${candidate.email ?? "Trống"}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                  Text(
                    'Phía: ${candidate.side} | Nguồn: ${candidate.guestSource}',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3ResolveConflicts() {
    if (_previewData == null) return Container();

    final conflicts = _previewData!['conflicts'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GIẢI QUYẾT XUNG ĐỘT DỮ LIỆU',
          style: TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Hãy chọn giá trị lưu lại cho từng thông tin bị xung đột giữa hai khách mời.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _buildConflictResolver('Họ và tên:', 'name', conflicts['name'], _resolvedName, (val) => setState(() => _resolvedName = val)),
        _buildConflictResolver('Số điện thoại:', 'phone', conflicts['phone'], _resolvedPhone, (val) => setState(() => _resolvedPhone = val)),
        _buildConflictResolver('Email:', 'email', conflicts['email'], _resolvedEmail, (val) => setState(() => _resolvedEmail = val)),
        _buildConflictResolver('Phía khách mời:', 'side', conflicts['side'], _resolvedSide, (val) => setState(() => _resolvedSide = val)),
        _buildConflictResolver('Nguồn khách mời:', 'guest_source', conflicts['guest_source'], _resolvedSource, (val) => setState(() => _resolvedSource = val)),
        _buildGroupIdConflictResolver(conflicts['primary_group_id']),
        _buildPartyIdConflictResolver(conflicts['invitation_party_id']),
      ],
    );
  }

  Widget _buildConflictResolver(
    String title,
    String fieldKey,
    dynamic conflictMeta,
    String? currentSelected,
    ValueChanged<String?> onChanged,
  ) {
    final bool hasConflict = conflictMeta['has_conflict'] as bool;
    final val1 = _guest1!.toJson()[fieldKey] as String?;
    final val2 = _guest2!.toJson()[fieldKey] as String?;

    if (!hasConflict) {
      return Container(); // No conflict, hide resolver
    }

    return Card(
      color: Colors.white.withOpacity(0.01),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.04))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildResolutionRadio(val1 ?? 'Trống/Null', val1, currentSelected, onChanged, _guest1!.name),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildResolutionRadio(val2 ?? 'Trống/Null', val2, currentSelected, onChanged, _guest2!.name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupIdConflictResolver(dynamic conflictMeta) {
    final bool hasConflict = conflictMeta['has_conflict'] as bool;
    if (!hasConflict) return Container();

    final g1 = widget.groups.firstWhere((g) => g.id == _guest1!.primaryGroupId, orElse: () => PrimaryGroupModel(id: '', weddingId: '', name: 'Trống/Null', createdAt: DateTime.now()));
    final g2 = widget.groups.firstWhere((g) => g.id == _guest2!.primaryGroupId, orElse: () => PrimaryGroupModel(id: '', weddingId: '', name: 'Trống/Null', createdAt: DateTime.now()));

    return Card(
      color: Colors.white.withOpacity(0.01),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.04))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhóm quan hệ:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildResolutionRadio(g1.name, _guest1!.primaryGroupId, _resolvedGroupId, (val) => setState(() => _resolvedGroupId = val), _guest1!.name),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildResolutionRadio(g2.name, _guest2!.primaryGroupId, _resolvedGroupId, (val) => setState(() => _resolvedGroupId = val), _guest2!.name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyIdConflictResolver(dynamic conflictMeta) {
    final bool hasConflict = conflictMeta['has_conflict'] as bool;
    if (!hasConflict) return Container();

    final p1 = widget.parties.firstWhere((p) => p.id == _guest1!.invitationPartyId, orElse: () => InvitationPartyModel(id: '', weddingId: '', displayName: 'Khách lẻ (Unassigned)', invitedCount: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
    final p2 = widget.parties.firstWhere((p) => p.id == _guest2!.invitationPartyId, orElse: () => InvitationPartyModel(id: '', weddingId: '', displayName: 'Khách lẻ (Unassigned)', invitedCount: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));

    return Card(
      color: Colors.white.withOpacity(0.01),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.04))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhóm mời / Hộ:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildResolutionRadio(p1.displayName, _guest1!.invitationPartyId, _resolvedPartyId, (val) => setState(() => _resolvedPartyId = val), _guest1!.name),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildResolutionRadio(p2.displayName, _guest2!.invitationPartyId, _resolvedPartyId, (val) => setState(() => _resolvedPartyId = val), _guest2!.name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionRadio(
    String displayText,
    String? value,
    String? currentSelected,
    ValueChanged<String?> onChanged,
    String ownerName,
  ) {
    final isSelected = currentSelected == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C6FF).withOpacity(0.05) : Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF00C6FF).withOpacity(0.3) : Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            Radio<String?>(
              value: value,
              groupValue: currentSelected,
              activeColor: const Color(0xFF00C6FF),
              onChanged: onChanged,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayText, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Từ: $ownerName', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4ReviewCommit() {
    final groupName = _resolvedGroupId == null
        ? 'Chưa gán nhóm (NONE)'
        : widget.groups.firstWhere((g) => g.id == _resolvedGroupId, orElse: () => PrimaryGroupModel(id: '', weddingId: '', name: 'Trống/Null', createdAt: DateTime.now())).name;
    final partyName = _resolvedPartyId == null
        ? 'Khách lẻ (Unassigned)'
        : widget.parties.firstWhere((p) => p.id == _resolvedPartyId, orElse: () => InvitationPartyModel(id: '', weddingId: '', displayName: 'Trống/Null', invitedCount: 0, createdAt: DateTime.now(), updatedAt: DateTime.now())).displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TỔNG HỢP TÁC ĐỘNG GỘP KHÁCH MỜI',
          style: TextStyle(color: Color(0xFF00C6FF), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        const Text(
          'Vui lòng rà soát lại thông tin hồ sơ khách mời gộp cuối cùng:',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewRow('Họ và tên:', _resolvedName!),
              _buildReviewRow('Số điện thoại:', _resolvedPhone ?? 'Trống (Null)'),
              _buildReviewRow('Email:', _resolvedEmail ?? 'Trống (Null)'),
              _buildReviewRow('Phía khách:', _resolvedSide!),
              _buildReviewRow('Nguồn khách:', _resolvedSource!),
              _buildReviewRow('Nhóm quan hệ:', groupName),
              _buildReviewRow('Nhóm mời / Hộ:', partyName),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Quy tắc an toàn vật lý của Merger:',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const BulletPoint3(text: 'Khách phụ sẽ bị xóa cứng (hard-delete) khỏi cơ sở dữ liệu.'),
        const BulletPoint3(text: 'Nhóm mời (Invitation Party) của cả hai khách vẫn sẽ được giữ lại, Invited Count không bao giờ tự ý thay đổi.'),
        const BulletPoint3(text: 'RSVP và phản hồi sự kiện của các nhóm mời sẽ được bảo toàn nguyên vẹn, không chuyển đổi chủ sở hữu.'),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
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
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final bool isFirstStep = _step == 1;
    final bool isLastStep = _step == 4;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          if (!isFirstStep) ...[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() {
                    _step--;
                  });
                },
                child: const Text('Quay lại', style: TextStyle(color: Colors.white70)),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C6FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (_step == 1) {
                  if (_guest1 == null || _guest2 == null) {
                    setState(() {
                      _errorMessage = 'Vui lòng chọn đầy đủ 2 khách mời';
                    });
                    return;
                  }
                  setState(() {
                    _survivor = _guest1;
                    _secondary = _guest2;
                    _step = 2;
                  });
                } else if (_step == 2) {
                  _fetchPreview();
                } else if (_step == 3) {
                  setState(() {
                    _step = 4;
                  });
                } else if (isLastStep) {
                  _handleCommit();
                }
              },
              child: Text(
                isLastStep ? 'Xác nhận gộp' : 'Tiếp tục',
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BulletPoint3 extends StatelessWidget {
  final String text;
  const BulletPoint3({super.key, required this.text});

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
