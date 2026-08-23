import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/guest_model.dart';
import '../models/invitation_model.dart';
import '../models/invitation_party_model.dart';
import '../services/supabase_service.dart';

class InvitationManagementScreen extends StatefulWidget {
  final String weddingId;
  final List<InvitationPartyModel> parties;
  final List<GuestModel> guests;

  const InvitationManagementScreen({
    super.key,
    required this.weddingId,
    required this.parties,
    required this.guests,
  });

  @override
  State<InvitationManagementScreen> createState() =>
      _InvitationManagementScreenState();
}

class _InvitationManagementScreenState
    extends State<InvitationManagementScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<WeddingEventInvitationOption> _events = [];
  List<InvitationModel> _invitations = [];
  List<InvitationTargetingModel> _targetings = [];
  final Map<String, Set<String>> _selectedTargetsByInvitation = {};
  final Map<String, String> _sessionLinksByInvitation = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final events = await SupabaseService.instance.fetchInvitationEventOptions(
        widget.weddingId,
      );
      final invitations = await SupabaseService.instance.fetchInvitations(
        widget.weddingId,
      );
      final targetings = await SupabaseService.instance
          .fetchInvitationTargetings(widget.weddingId);

      final selected = <String, Set<String>>{};
      for (final invitation in invitations) {
        selected[invitation.id] = targetings
            .where((targeting) => targeting.invitationId == invitation.id)
            .map((targeting) => targeting.weddingEventId)
            .toSet();
      }

      setState(() {
        _events = events;
        _invitations = invitations;
        _targetings = targetings;
        _selectedTargetsByInvitation
          ..clear()
          ..addAll(selected);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Không thể tải cấu hình thiệp mời. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  InvitationModel? _invitationForParty(String partyId) {
    for (final invitation in _invitations) {
      if (invitation.invitationPartyId == partyId) return invitation;
    }
    return null;
  }

  List<GuestModel> _membersForParty(String partyId) {
    return widget.guests
        .where((guest) => guest.invitationPartyId == partyId)
        .toList();
  }

  Future<void> _createInvitation(InvitationPartyModel party) async {
    try {
      final invitation = await SupabaseService.instance.createInvitation(
        weddingId: widget.weddingId,
        invitationPartyId: party.id,
      );
      setState(() {
        _invitations = [..._invitations, invitation];
        _selectedTargetsByInvitation[invitation.id] = <String>{};
      });
      _showSnack('Đã tạo bản nháp thiệp mời.');
    } catch (_) {
      _showSnack('Không thể tạo thiệp mời cho nhóm này.');
    }
  }

  Future<void> _saveTargets(InvitationModel invitation) async {
    try {
      await SupabaseService.instance.replaceInvitationTargetings(
        weddingId: widget.weddingId,
        invitationId: invitation.id,
        targetEventIds: _selectedTargetsByInvitation[invitation.id] ?? {},
      );
      await _loadData();
      _showSnack('Đã lưu sự kiện được mời.');
    } catch (_) {
      _showSnack('Không thể lưu sự kiện được mời.');
    }
  }

  Future<void> _moveToReady(InvitationModel invitation) async {
    try {
      await SupabaseService.instance.updateInvitationStatus(
        invitationId: invitation.id,
        status: InvitationStatus.ready,
      );
      await _loadData();
      _showSnack('Thiệp đã chuyển sang trạng thái sẵn sàng.');
    } catch (_) {
      _showSnack(
        'Chưa thể chuyển READY. Hãy kiểm tra tên nhóm, số người mời và sự kiện.',
      );
    }
  }

  Future<void> _markAsSent(InvitationModel invitation) async {
    final confirmed = await _confirm(
      title: 'Đánh dấu đã gửi?',
      message: 'Hành động này ghi nhận bạn đã chủ động gửi thiệp. Sao chép hoặc chia sẻ link không tự đánh dấu đã gửi.',
      actionLabel: 'Đánh dấu đã gửi',
    );
    if (!confirmed) return;

    try {
      await SupabaseService.instance.updateInvitationStatus(
        invitationId: invitation.id,
        status: InvitationStatus.markedAsSent,
      );
      await _loadData();
      _showSnack('Đã đánh dấu thiệp là đã gửi.');
    } catch (_) {
      _showSnack('Không thể đánh dấu đã gửi lúc này.');
    }
  }

  Future<void> _regenerateCredential(InvitationModel invitation) async {
    final hasSessionLink = _sessionLinksByInvitation.containsKey(invitation.id);
    final confirmed = await _confirm(
      title: hasSessionLink ? 'Tái tạo liên kết?' : 'Tạo liên kết thiệp?',
      message: 'Hệ thống sẽ sinh link mới. Nếu đã có link cũ, link cũ sẽ ngừng hoạt động; thiệp và lịch sử vẫn được giữ nguyên.',
      actionLabel: hasSessionLink ? 'Tái tạo link' : 'Tạo link',
    );
    if (!confirmed) return;

    try {
      final result = await SupabaseService.instance
          .regenerateInvitationCredential(invitation.id);
      setState(() {
        _sessionLinksByInvitation[invitation.id] = result.sharePath;
      });
      _showSnack(
        'Đã tạo link mới. Link chỉ được giữ trong phiên màn hình này.',
      );
    } catch (_) {
      _showSnack(
        'Không thể tạo link. Thiệp cần ở trạng thái READY hoặc đã gửi.',
      );
    }
  }

  Future<void> _copyLink(InvitationModel invitation) async {
    final link = _sessionLinksByInvitation[invitation.id];
    if (link == null) {
      _showSnack('Hãy tạo hoặc tái tạo link trước khi sao chép.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    _showSnack('Đã sao chép link. Trạng thái thiệp không bị đổi.');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: const Text(
          'Quản lý Thiệp mời',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Tải lại')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final activeEvents = _events.where((event) => event.isActive).length;
    final readyEvents = _events.where((event) => event.isRsvpReady).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF14213D), Color(0xFF12343B)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'M3 Invitation/Credential Foundation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nhóm mời: ${widget.parties.length} | Thiệp: ${_invitations.length} | Sự kiện active: $activeEvents | RSVP-ready: $readyEvents',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'Link raw chỉ hiển thị sau khi tạo/tái tạo trong phiên này và không được lưu cục bộ.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...widget.parties.map(_buildPartyCard),
      ],
    );
  }

  Widget _buildPartyCard(InvitationPartyModel party) {
    final invitation = _invitationForParty(party.id);
    final members = _membersForParty(party.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ExpansionTile(
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white38,
        title: Text(
          party.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Mời ${party.invitedCount} | ${members.length} named guests | ${invitation == null ? "Chưa có thiệp" : InvitationStatus.label(invitation.status)}',
          style: const TextStyle(color: Colors.white54),
        ),
        children: [
          const Divider(color: Colors.white10),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nhóm trống vẫn hợp lệ nếu tên hiển thị và Invited Count đã đúng.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          if (invitation == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _createInvitation(party),
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Tạo thiệp DRAFT'),
              ),
            )
          else
            _buildInvitationEditor(invitation),
        ],
      ),
    );
  }

  Widget _buildInvitationEditor(InvitationModel invitation) {
    final selected = _selectedTargetsByInvitation.putIfAbsent(
      invitation.id,
      () => _targetings
          .where((targeting) => targeting.invitationId == invitation.id)
          .map((targeting) => targeting.weddingEventId)
          .toSet(),
    );
    final sessionLink = _sessionLinksByInvitation[invitation.id];
    final canReady =
        InvitationStatus.canMoveToReady(invitation) && selected.isNotEmpty;
    final canCredential =
        invitation.status == InvitationStatus.ready ||
        invitation.status == InvitationStatus.markedAsSent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(invitation.status),
              if (invitation.markedSentAt != null)
                _infoChip('Marked: ${invitation.markedSentAt!.toLocal()}'),
              if (invitation.firstViewedAt != null)
                _infoChip('Viewed: ${invitation.firstViewedAt!.toLocal()}'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Sự kiện trên thiệp',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._events.map((event) {
            return CheckboxListTile(
              value: selected.contains(event.id),
              onChanged: event.isActive
                  ? (value) {
                      setState(() {
                        if (value ?? false) {
                          selected.add(event.id);
                        } else {
                          selected.remove(event.id);
                        }
                      });
                    }
                  : null,
              title: Text(
                event.name,
                style: TextStyle(
                  color: event.isActive ? Colors.white : Colors.white30,
                ),
              ),
              subtitle: Text(
                event.readinessLabel,
                style: TextStyle(
                  color: event.isRsvpReady
                      ? const Color(0xFF4ADE80)
                      : event.isActive
                      ? const Color(0xFFFACC15)
                      : Colors.white30,
                  fontSize: 12,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: const Color(0xFF00C6FF),
            );
          }),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _saveTargets(invitation),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Lưu sự kiện'),
              ),
              FilledButton.icon(
                onPressed: canReady ? () => _moveToReady(invitation) : null,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Chuyển READY'),
              ),
              OutlinedButton.icon(
                onPressed: InvitationStatus.canMarkAsSent(invitation)
                    ? () => _markAsSent(invitation)
                    : null,
                icon: const Icon(Icons.outgoing_mail),
                label: const Text('Mark as Sent'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: canCredential
                    ? () => _regenerateCredential(invitation)
                    : null,
                icon: const Icon(Icons.vpn_key_rounded),
                label: Text(sessionLink == null ? 'Tạo link' : 'Tái tạo link'),
              ),
              OutlinedButton.icon(
                onPressed: sessionLink == null
                    ? null
                    : () => _copyLink(invitation),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Sao chép link'),
              ),
            ],
          ),
          if (sessionLink != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              sessionLink,
              style: const TextStyle(color: Color(0xFF00C6FF)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Chip(
      label: Text(InvitationStatus.label(status)),
      backgroundColor: status == InvitationStatus.markedAsSent
          ? const Color(0xFF4ADE80)
          : status == InvitationStatus.ready
          ? const Color(0xFF00C6FF)
          : const Color(0xFFFACC15),
    );
  }

  Widget _infoChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
    );
  }
}
