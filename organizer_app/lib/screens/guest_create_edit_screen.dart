import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../models/guest_model.dart';
import '../models/primary_group_model.dart';
import '../models/invitation_party_model.dart';
import 'party_move_preview_screen.dart';

class GuestCreateEditScreen extends StatefulWidget {
  final String weddingId;
  final GuestModel? guest; // null means create new
  final List<PrimaryGroupModel> groups;
  final List<InvitationPartyModel> parties;

  const GuestCreateEditScreen({
    super.key,
    required this.weddingId,
    this.guest,
    required this.groups,
    required this.parties,
  });

  @override
  State<GuestCreateEditScreen> createState() => _GuestCreateEditScreenState();
}

class _GuestCreateEditScreenState extends State<GuestCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  String _side = 'COMMON';
  String _guestSource = 'OTHER';
  String? _selectedGroupId;
  String? _selectedPartyId;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.guest?.name ?? '');
    _phoneController = TextEditingController(text: widget.guest?.phone ?? '');
    _emailController = TextEditingController(text: widget.guest?.email ?? '');

    if (widget.guest != null) {
      _side = widget.guest!.side;
      _guestSource = widget.guest!.guestSource;
      _selectedGroupId = widget.guest!.primaryGroupId;
      _selectedPartyId = widget.guest!.invitationPartyId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim();
      final email = _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim();

      // Check duplicates first
      final duplicates = await SupabaseService.instance.checkGuestDuplicates(
        weddingId: widget.weddingId,
        name: name,
        phone: phone,
        email: email,
      );

      // Filter out self when checking duplicates during edit
      final realDuplicates = duplicates
          .where((d) => widget.guest == null || d['id'] != widget.guest!.id)
          .toList();

      if (realDuplicates.isNotEmpty) {
        setState(() => _submitting = false);
        final proceed = await _showDuplicateWarningDialog(realDuplicates);
        if (!mounted) return;
        if (!proceed) return;
        setState(() => _submitting = true);
      }

      final guestToSave = GuestModel(
        id:
            widget.guest?.id ??
            '', // empty for insert, will be ignored by toJson
        weddingId: widget.weddingId,
        name: name,
        phone: phone,
        email: email,
        side: _side,
        guestSource: _guestSource,
        primaryGroupId: _selectedGroupId,
        invitationPartyId: _selectedPartyId,
        createdAt: DateTime.now(), // placeholder, overwritten by DB
        updatedAt: DateTime.now(), // placeholder
      );

      if (widget.guest == null) {
        await SupabaseService.instance.createGuest(guestToSave);
      } else {
        await SupabaseService.instance.updateGuest(guestToSave);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể lưu khách mời. Vui lòng kiểm tra dữ liệu và thử lại.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<bool> _showDuplicateWarningDialog(
    List<Map<String, dynamic>> duplicates,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 10),
                  Text(
                    'Phát hiện trùng lặp',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hệ thống phát hiện khách mời có thể bị trùng thông tin với người khác trong đám cưới:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ...duplicates.map((d) {
                    final reason = d['match_reason'] as String;
                    String reasonText = 'Trùng lặp khác';
                    if (reason == 'TRUNG_SO_DIEN_THOAI') {
                      reasonText = 'Trùng số điện thoại';
                    } else if (reason == 'TRUNG_EMAIL') {
                      reasonText = 'Trùng email';
                    } else if (reason == 'TRUNG_TEN') {
                      reasonText = 'Trùng tên';
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orangeAccent.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d['name'] as String? ?? 'Không rõ tên',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SĐT: ${d['phone'] ?? "Trống"} | Email: ${d['email'] ?? "Trống"}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lý do: $reasonText',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Text(
                    'Bạn có chắc chắn muốn tiếp tục lưu?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Hủy bỏ',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5E7E),
                  ),
                  child: const Text(
                    'Vẫn lưu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.guest != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: Text(
          isEdit ? 'Sửa Khách mời' : 'Thêm Khách mới',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _submitting
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration(
                        'Họ và tên khách mời *',
                        Icons.person_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Vui lòng nhập họ tên';
                        if (val.trim().length > 50)
                          return 'Tên khách mời tối đa 50 ký tự';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone field
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(
                        'Số điện thoại (tùy chọn)',
                        Icons.phone_rounded,
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          // Simple regex to match phone format
                          final clean = val.replaceAll(RegExp(r'\D'), '');
                          if (clean.length < 8 || clean.length > 15)
                            return 'Số điện thoại không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildInputDecoration(
                        'Email (tùy chọn)',
                        Icons.email_rounded,
                      ),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(val.trim()))
                            return 'Email không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Side selection
                    const Text(
                      'Phía gia đình *',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSideDropdown(),
                    const SizedBox(height: 20),

                    // Guest Source selection
                    const Text(
                      'Nguồn mời (Khách của ai) *',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSourceDropdown(),
                    const SizedBox(height: 20),

                    // Primary Group assignment
                    const Text(
                      'Nhóm quan hệ chính',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildGroupDropdown(),
                    const SizedBox(height: 20),

                    // Invitation Party assignment
                    const Text(
                      'Nhóm mời / Hộ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPartyDropdown(),
                    const SizedBox(height: 36),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4EFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _handleSave,
                      child: const Text(
                        'Lưu thông tin',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6B4EFF), width: 1.5),
      ),
    );
  }

  Widget _buildSideDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _side,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (val) => setState(() => _side = val!),
          items: const [
            DropdownMenuItem(value: 'COMMON', child: Text('Chung (Common)')),
            DropdownMenuItem(
              value: 'BRIDE_SIDE',
              child: Text('Phía Cô dâu (Bride)'),
            ),
            DropdownMenuItem(
              value: 'GROOM_SIDE',
              child: Text('Phía Chú rể (Groom)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _guestSource,
          dropdownColor: const Color(0xFF1E293B),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (val) => setState(() => _guestSource = val!),
          items: const [
            DropdownMenuItem(value: 'BRIDE', child: Text('Cô dâu (Bride)')),
            DropdownMenuItem(value: 'GROOM', child: Text('Chú rể (Groom)')),
            DropdownMenuItem(
              value: 'BRIDE_PARENTS',
              child: Text('Bố mẹ Cô dâu'),
            ),
            DropdownMenuItem(
              value: 'GROOM_PARENTS',
              child: Text('Bố mẹ Chú rể'),
            ),
            DropdownMenuItem(value: 'OTHER', child: Text('Nguồn khác (Other)')),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedGroupId,
          dropdownColor: const Color(0xFF1E293B),
          hint: const Text(
            'Chọn nhóm quan hệ (tùy chọn)',
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (val) => setState(() => _selectedGroupId = val),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Không có nhóm (Unassigned)'),
            ),
            ...widget.groups.map(
              (grp) => DropdownMenuItem(value: grp.id, child: Text(grp.name)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyDropdown() {
    final bool hasExistingParty =
        widget.guest != null && widget.guest!.invitationPartyId != null;

    if (hasExistingParty) {
      final currentParty = widget.parties.firstWhere(
        (p) => p.id == widget.guest!.invitationPartyId,
        orElse: () => InvitationPartyModel(
          id: '',
          weddingId: '',
          displayName: 'Không xác định',
          invitedCount: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${currentParty.displayName} (Mời: ${currentParty.invitedCount})',
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: Color(0xFF00C6FF),
            ),
            label: const Text(
              'Di chuyển hoặc Gỡ nhóm mời...',
              style: TextStyle(color: Color(0xFF00C6FF), fontSize: 13),
            ),
            onPressed: () => _openPartyMoveDialog(currentParty),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedPartyId,
          dropdownColor: const Color(0xFF1E293B),
          hint: const Text(
            'Chọn nhóm mời / Hộ (tùy chọn)',
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (val) => setState(() => _selectedPartyId = val),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Khách lẻ độc lập (Unassigned)'),
            ),
            ...widget.parties.map(
              (prt) => DropdownMenuItem(
                value: prt.id,
                child: Text('${prt.displayName} (Mời: ${prt.invitedCount})'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPartyMoveDialog(InvitationPartyModel currentParty) {
    String? tempSelectedPartyId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            'Chọn nhóm mời đích',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn nhóm mời mới cho khách hoặc gỡ khỏi nhóm hiện tại để chuyển thành Khách lẻ:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: tempSelectedPartyId,
                    dropdownColor: const Color(0xFF1E293B),
                    hint: const Text(
                      'Chọn nhóm mời / Hộ',
                      style: TextStyle(color: Colors.white30, fontSize: 14),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    isExpanded: true,
                    onChanged: (val) =>
                        setDialogState(() => tempSelectedPartyId = val),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Gỡ khỏi nhóm (Khách lẻ)'),
                      ),
                      ...widget.parties
                          .where((p) => p.id != currentParty.id)
                          .map(
                            (prt) => DropdownMenuItem(
                              value: prt.id,
                              child: Text(
                                '${prt.displayName} (Mời: ${prt.invitedCount})',
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C6FF),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _navigateToPartyMovePreview(tempSelectedPartyId);
              },
              child: const Text(
                'Xem trước di chuyển',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToPartyMovePreview(String? targetPartyId) async {
    final targetName = targetPartyId == null
        ? null
        : widget.parties.firstWhere((p) => p.id == targetPartyId).displayName;

    final moved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PartyMovePreviewScreen(
          guestId: widget.guest!.id,
          guestName: widget.guest!.name,
          targetPartyId: targetPartyId,
          targetPartyName: targetName,
        ),
      ),
    );

    if (moved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Di chuyển nhóm mời thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }
}
