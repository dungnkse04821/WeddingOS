import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/primary_group_model.dart';
import 'group_delete_preview_screen.dart';

class GroupManagementScreen extends StatefulWidget {
  final String weddingId;

  const GroupManagementScreen({super.key, required this.weddingId});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;

  List<PrimaryGroupModel> _groups = [];
  PrimaryGroupModel? _editingGroup; // null means create new mode

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final data = await SupabaseService.instance.fetchPrimaryGroups(widget.weddingId);
      setState(() {
        _groups = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load groups: $e';
        _loading = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final name = _nameController.text.trim();

      if (_editingGroup == null) {
        // Create new
        await SupabaseService.instance.createPrimaryGroup(widget.weddingId, name);
      } else {
        // Edit name
        await SupabaseService.instance.updatePrimaryGroup(_editingGroup!.id, name);
      }

      _nameController.clear();
      setState(() {
        _editingGroup = null;
        _submitting = false;
      });

      _loadGroups();
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu nhóm: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _startEdit(PrimaryGroupModel grp) {
    setState(() {
      _editingGroup = grp;
      _nameController.text = grp.name;
    });
  }

  void _cancelEdit() {
    _nameController.clear();
    setState(() {
      _editingGroup = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      appBar: AppBar(
        title: const Text('Nhóm Quan hệ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4EFF)))
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    // Create / Edit Form Card
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _editingGroup == null ? 'Tạo Nhóm Quan hệ mới' : 'Sửa Nhóm: ${_editingGroup!.name}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _nameController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: 'Nhập tên nhóm (Ví dụ: Bạn đá bóng, Đồng nghiệp...)',
                                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.03),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tên nhóm';
                                        if (val.trim().length > 100) return 'Tên nhóm tối đa 100 ký tự';
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (_editingGroup != null) ...[
                                    TextButton(
                                      onPressed: _cancelEdit,
                                      child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6B4EFF),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _submitting ? null : _handleSubmit,
                                    child: Text(_editingGroup == null ? 'Thêm Nhóm' : 'Cập nhật', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Primary Group List
                    Expanded(
                      child: _groups.isEmpty
                          ? const Center(child: Text('Chưa có nhóm quan hệ nào được tạo.', style: TextStyle(color: Colors.white38)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _groups.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final grp = _groups[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.02),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.group_work_rounded, color: Color(0xFF00C6FF), size: 18),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          grp.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_rounded, color: Colors.white54, size: 18),
                                        onPressed: () => _startEdit(grp),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                        onPressed: () async {
                                          final deleted = await Navigator.of(context).push<bool>(
                                            MaterialPageRoute(
                                              builder: (_) => GroupDeletePreviewScreen(
                                                groupId: grp.id,
                                                groupName: grp.name,
                                              ),
                                            ),
                                          );
                                          if (deleted == true) {
                                            _loadGroups();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
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
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadGroups,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
              child: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }
}
