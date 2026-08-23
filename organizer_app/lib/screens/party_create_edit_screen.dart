import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/invitation_party_model.dart';
import '../models/guest_model.dart';

class PartyCreateEditScreen extends StatefulWidget {
  final String weddingId;
  final InvitationPartyModel? party; // null means create new
  final List<GuestModel> allGuests;

  const PartyCreateEditScreen({
    super.key,
    required this.weddingId,
    this.party,
    required this.allGuests,
  });

  @override
  State<PartyCreateEditScreen> createState() => _PartyCreateEditScreenState();
}

class _PartyCreateEditScreenState extends State<PartyCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _invitedCountController;

  bool _submitting = false;
  List<GuestModel> _currentMembers = [];
  List<GuestModel> _unassignedGuests = [];

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.party?.displayName ?? '');
    _invitedCountController = TextEditingController(text: widget.party?.invitedCount.toString() ?? '1');

    _loadPartyMembers();
  }

  void _loadPartyMembers() {
    // Current members of this party
    _currentMembers = widget.allGuests.where((g) => widget.party != null && g.invitationPartyId == widget.party!.id).toList();

    // Guests in the wedding who are unassigned (party ID is null)
    _unassignedGuests = widget.allGuests.where((g) => g.invitationPartyId == null).toList();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _invitedCountController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final displayName = _displayNameController.text.trim();
      final invitedCount = int.parse(_invitedCountController.text.trim());

      if (widget.party == null) {
        // Create new party
        await SupabaseService.instance.createInvitationParty(
          weddingId: widget.weddingId,
          displayName: displayName,
          invitedCount: invitedCount,
        );
      } else {
        // Update existing party
        // Invariant: does NOT silently change invited_count based on named guests
        await SupabaseService.instance.updateInvitationParty(
          partyId: widget.party!.id,
          displayName: displayName,
          invitedCount: invitedCount,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu nhóm mời: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _toggleGuestAssignment(GuestModel guest, bool assign) async {
    setState(() => _submitting = true);

    try {
      final updatedGuest = GuestModel(
        id: guest.id,
        weddingId: guest.weddingId,
        name: guest.name,
        phone: guest.phone,
        email: guest.email,
        side: guest.side,
        guestSource: guest.guestSource,
        primaryGroupId: guest.primaryGroupId,
        invitationPartyId: assign ? widget.party!.id : null,
        createdAt: guest.createdAt,
        updatedAt: DateTime.now(),
      );

      // Mutate guest's party link. The party's invitedCount MUST NOT change (preserved).
      await SupabaseService.instance.updateGuest(updatedGuest);

      // Dynamically update local lists
      setState(() {
        if (assign) {
          _unassignedGuests.removeWhere((g) => g.id == guest.id);
          _currentMembers.add(updatedGuest);
        } else {
          _currentMembers.removeWhere((g) => g.id == guest.id);
          _unassignedGuests.add(updatedGuest);
        }
        _submitting = false;
      });
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi gán khách mời: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.party != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa Nhóm mời / Hộ' : 'Thêm Nhóm mời mới', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _submitting
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Display name field
                    TextFormField(
                      controller: _displayNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('Tên hiển thị thiệp mời * (Ví dụ: Gia đình bác Tư, Anh Nam & bạn)', Icons.card_membership_rounded),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên hiển thị nhóm';
                        if (val.trim().length > 100) return 'Tên nhóm tối đa 100 ký tự';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Invited count field
                    TextFormField(
                      controller: _invitedCountController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Số lượng người mời thực tế * (Hạn mức chỗ ngồi)', Icons.tag_rounded),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số người mời';
                        final num = int.tryParse(val.trim());
                        if (num == null || num < 0) return 'Số người mời phải là số nguyên dương >= 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Notice on Invited Count invariant
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C6FF).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00C6FF).withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF00C6FF), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Thay đổi danh sách thành viên bên dưới sẽ không tự động làm thay đổi hạn mức Số người mời thực tế đã chốt.',
                              style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Member list (only if editing an existing party)
                    if (isEdit) ...[
                      Text('Thành viên nhóm này (${_currentMembers.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _currentMembers.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text('Không có thành viên nào. Hãy thêm khách mời lẻ phía dưới.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _currentMembers.length,
                              itemBuilder: (context, index) {
                                final guest = _currentMembers[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(guest.name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  subtitle: Text('SĐT: ${guest.phone ?? "Trống"} | Phía: ${guest.side}', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                                );
                              },
                            ),
                      const SizedBox(height: 24),

                      Text('Khách lẻ chưa gán nhóm (${_unassignedGuests.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _unassignedGuests.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Text('Tất cả khách mời đã được gán nhóm.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            )
                          : Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.04)),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _unassignedGuests.length,
                                itemBuilder: (context, index) {
                                  final guest = _unassignedGuests[index];
                                  return ListTile(
                                    title: Text(guest.name, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    subtitle: Text('Phía: ${guest.side}', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF00C6FF)),
                                      onPressed: () => _toggleGuestAssignment(guest, true),
                                    ),
                                  );
                                },
                              ),
                            ),
                      const SizedBox(height: 24),
                    ],

                    // Submit button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4EFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _handleSave,
                      child: const Text('Lưu thông tin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF6B4EFF), width: 1.5)),
    );
  }
}
