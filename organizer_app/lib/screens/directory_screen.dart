import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../models/guest_model.dart';
import '../models/invitation_party_model.dart';
import '../models/primary_group_model.dart';
import 'guest_create_edit_screen.dart';
import 'party_create_edit_screen.dart';
import 'group_management_screen.dart';
import 'guest_merge_screen.dart';
import 'guest_import_screen.dart';
import 'invitation_management_screen.dart';

class DirectoryScreen extends StatefulWidget {
  final String weddingId;

  const DirectoryScreen({super.key, required this.weddingId});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _errorMessage;

  List<GuestModel> _guests = [];
  List<InvitationPartyModel> _parties = [];
  List<PrimaryGroupModel> _groups = [];

  // Search & Filter state
  String _guestSearchQuery = '';
  String _partySearchQuery = '';
  String _selectedSide = 'ALL';
  String _selectedGroupId = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final guestsData = await SupabaseService.instance.fetchGuests(
        widget.weddingId,
      );
      final partiesData = await SupabaseService.instance.fetchInvitationParties(
        widget.weddingId,
      );
      final groupsData = await SupabaseService.instance.fetchPrimaryGroups(
        widget.weddingId,
      );

      setState(() {
        _guests = guestsData;
        _parties = partiesData;
        _groups = groupsData;
        _loading = false;
      });
    } catch (e) {
      final failure = await SupabaseService.instance.handleOperationalError(e);
      setState(() {
        _errorMessage = failure.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: const Text(
          'Danh bạ Khách mời',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.mark_email_read_rounded,
              color: Color(0xFF00C6FF),
            ),
            tooltip: 'Quản lý thiệp mời',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InvitationManagementScreen(
                    weddingId: widget.weddingId,
                    parties: _parties,
                    guests: _guests,
                  ),
                ),
              );
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.upload_file_rounded,
              color: Color(0xFF00C6FF),
            ),
            tooltip: 'Nhập Excel khách mời',
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GuestImportScreen(
                    weddingId: widget.weddingId,
                    existingGuests: _guests,
                  ),
                ),
              );
              if (!context.mounted) return;
              if (result != null) {
                await _loadData();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Đã nhập danh sách khách mời và làm mới danh bạ.',
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.merge_type_rounded,
              color: Color(0xFF00C6FF),
            ),
            tooltip: 'Gộp khách trùng lặp',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GuestMergeScreen(
                    guests: _guests,
                    groups: _groups,
                    parties: _parties,
                  ),
                ),
              );
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.group_work_rounded,
              color: Color(0xFF00C6FF),
            ),
            tooltip: 'Quản lý Nhóm quan hệ',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      GroupManagementScreen(weddingId: widget.weddingId),
                ),
              );
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00C6FF),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF00C6FF),
          tabs: const [
            Tab(text: 'Khách mời cá nhân'),
            Tab(text: 'Nhóm mời / Hộ'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
            )
          : _errorMessage != null
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [_buildGuestTab(), _buildPartyTab()],
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
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF),
              ),
              child: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestTab() {
    final filteredGuests = _guests.where((g) {
      final matchSearch =
          g.name.toLowerCase().contains(_guestSearchQuery.toLowerCase()) ||
          (g.phone != null && g.phone!.contains(_guestSearchQuery)) ||
          (g.email != null &&
              g.email!.toLowerCase().contains(_guestSearchQuery.toLowerCase()));
      final matchSide = _selectedSide == 'ALL' || g.side == _selectedSide;
      final matchGroup =
          _selectedGroupId == 'ALL' || g.primaryGroupId == _selectedGroupId;
      return matchSearch && matchSide && matchGroup;
    }).toList();

    return Column(
      children: [
        // Search & Filters Header
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _guestSearchQuery = val),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, SĐT, email...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSide,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (val) =>
                              setState(() => _selectedSide = val!),
                          items: const [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Text('Tất cả phía'),
                            ),
                            DropdownMenuItem(
                              value: 'COMMON',
                              child: Text('Chung (Common)'),
                            ),
                            DropdownMenuItem(
                              value: 'BRIDE_SIDE',
                              child: Text('Nhà Gái (Bride)'),
                            ),
                            DropdownMenuItem(
                              value: 'GROOM_SIDE',
                              child: Text('Nhà Trai (Groom)'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGroupId,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          onChanged: (val) =>
                              setState(() => _selectedGroupId = val!),
                          items: [
                            const DropdownMenuItem(
                              value: 'ALL',
                              child: Text('Tất cả nhóm'),
                            ),
                            ..._groups.map(
                              (grp) => DropdownMenuItem(
                                value: grp.id,
                                child: Text(grp.name),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Guest List
        Expanded(
          child: filteredGuests.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy khách mời nào.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredGuests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final guest = filteredGuests[index];
                    final groupName = _groups
                        .firstWhere(
                          (g) => g.id == guest.primaryGroupId,
                          orElse: () => PrimaryGroupModel(
                            id: '',
                            weddingId: '',
                            name: 'Chưa có nhóm',
                            createdAt: DateTime.now(),
                          ),
                        )
                        .name;
                    final partyName = _parties
                        .firstWhere(
                          (p) => p.id == guest.invitationPartyId,
                          orElse: () => InvitationPartyModel(
                            id: '',
                            weddingId: '',
                            displayName: 'Khách lẻ',
                            invitedCount: 0,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        )
                        .displayName;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              guest.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Side indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: guest.side == 'BRIDE_SIDE'
                                    ? const Color(0xFFFF5E7E).withOpacity(0.15)
                                    : guest.side == 'GROOM_SIDE'
                                    ? const Color(0xFF6B4EFF).withOpacity(0.15)
                                    : Colors.white12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                guest.side == 'BRIDE_SIDE'
                                    ? 'Nhà Gái'
                                    : guest.side == 'GROOM_SIDE'
                                    ? 'Nhà Trai'
                                    : 'Chung',
                                style: TextStyle(
                                  color: guest.side == 'BRIDE_SIDE'
                                      ? const Color(0xFFFF5E7E)
                                      : guest.side == 'GROOM_SIDE'
                                      ? const Color(0xFF6B4EFF)
                                      : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Nhóm: $groupName | Thiệp: $partyName',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            if (guest.phone != null && guest.phone!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  'SĐT: ${guest.phone}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_hasDuplicateWarning(guest))
                              IconButton(
                                icon: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orangeAccent,
                                ),
                                tooltip: 'Gộp trùng lặp',
                                onPressed: () async {
                                  final other = _guests.firstWhere(
                                    (g) =>
                                        g.id != guest.id &&
                                        ((guest.normalizedPhone != null &&
                                                guest
                                                    .normalizedPhone!
                                                    .isNotEmpty &&
                                                g.normalizedPhone ==
                                                    guest.normalizedPhone) ||
                                            (guest.normalizedEmail != null &&
                                                guest
                                                    .normalizedEmail!
                                                    .isNotEmpty &&
                                                g.normalizedEmail ==
                                                    guest.normalizedEmail)),
                                    orElse: () => GuestModel(
                                      id: '',
                                      weddingId: '',
                                      name: '',
                                      side: 'COMMON',
                                      guestSource: 'OTHER',
                                      createdAt: DateTime.now(),
                                      updatedAt: DateTime.now(),
                                    ),
                                  );

                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => GuestMergeScreen(
                                        guests: _guests,
                                        groups: _groups,
                                        parties: _parties,
                                        initialGuest1: guest,
                                        initialGuest2: other.id.isNotEmpty
                                            ? other
                                            : null,
                                      ),
                                    ),
                                  );
                                  _loadData();
                                },
                              ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white30,
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GuestCreateEditScreen(
                                weddingId: widget.weddingId,
                                guest: guest,
                                groups: _groups,
                                parties: _parties,
                              ),
                            ),
                          );
                          _loadData();
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPartyTab() {
    final filteredParties = _parties.where((p) {
      return p.displayName.toLowerCase().contains(
        _partySearchQuery.toLowerCase(),
      );
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            onChanged: (val) => setState(() => _partySearchQuery = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm nhóm mời...',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white54,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),

        // Party List
        Expanded(
          child: filteredParties.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy nhóm mời nào.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredParties.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final party = filteredParties[index];
                    final members = _guests
                        .where((g) => g.invitationPartyId == party.id)
                        .toList();

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Text(
                              party.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C6FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Mời: ${party.invitedCount}',
                                style: const TextStyle(
                                  color: Color(0xFF00C6FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          members.isEmpty
                              ? 'Chưa khai báo thành viên nào'
                              : 'Thành viên: ${members.map((m) => m.name).join(', ')}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        iconColor: Colors.white54,
                        collapsedIconColor: Colors.white38,
                        children: [
                          const Divider(color: Colors.white10),
                          if (members.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text(
                                'Nhóm trống (0 named guests). Bạn có thể bấm Sửa để gán khách vào nhóm này.',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            ...members.map(
                              (m) => ListTile(
                                title: Text(
                                  m.name,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  'SĐT: ${m.phone ?? "Trống"} | Phía: ${m.side == "BRIDE_SIDE"
                                      ? "Nhà Gái"
                                      : m.side == "GROOM_SIDE"
                                      ? "Nhà Trai"
                                      : "Chung"}',
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 11,
                                  ),
                                ),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => GuestCreateEditScreen(
                                        weddingId: widget.weddingId,
                                        guest: m,
                                        groups: _groups,
                                        parties: _parties,
                                      ),
                                    ),
                                  );
                                  _loadData();
                                },
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 14,
                                    color: Color(0xFF00C6FF),
                                  ),
                                  label: const Text(
                                    'Sửa Nhóm Mời',
                                    style: TextStyle(
                                      color: Color(0xFF00C6FF),
                                      fontSize: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PartyCreateEditScreen(
                                          weddingId: widget.weddingId,
                                          party: party,
                                          allGuests: _guests,
                                        ),
                                      ),
                                    );
                                    _loadData();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  bool _hasDuplicateWarning(GuestModel guest) {
    if (guest.normalizedPhone != null && guest.normalizedPhone!.isNotEmpty) {
      final dupPhone = _guests.where(
        (g) => g.id != guest.id && g.normalizedPhone == guest.normalizedPhone,
      );
      if (dupPhone.isNotEmpty) return true;
    }
    if (guest.normalizedEmail != null && guest.normalizedEmail!.isNotEmpty) {
      final dupEmail = _guests.where(
        (g) => g.id != guest.id && g.normalizedEmail == guest.normalizedEmail,
      );
      if (dupEmail.isNotEmpty) return true;
    }
    return false;
  }
}
