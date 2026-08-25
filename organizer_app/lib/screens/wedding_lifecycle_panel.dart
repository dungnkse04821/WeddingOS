import 'package:flutter/material.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import '../services/wedding_lifecycle_service.dart';

bool weddingNamesMatch(String expected, String candidate) {
  return unorm.nfc(expected.trim()).toLowerCase() ==
      unorm.nfc(candidate.trim()).toLowerCase();
}

class WeddingLifecyclePanel extends StatefulWidget {
  const WeddingLifecyclePanel({
    super.key,
    required this.weddingId,
    required this.weddingName,
    required this.status,
    required this.isOwner,
    required this.onArchived,
    required this.onDeleted,
    required this.onSwitchWedding,
    this.service,
  });

  final String weddingId;
  final String weddingName;
  final String status;
  final bool isOwner;
  final VoidCallback onArchived;
  final Future<void> Function() onDeleted;
  final VoidCallback onSwitchWedding;
  final WeddingLifecycleService? service;

  @override
  State<WeddingLifecyclePanel> createState() => _WeddingLifecyclePanelState();
}

class _WeddingLifecyclePanelState extends State<WeddingLifecyclePanel> {
  bool _busy = false;
  bool _retryRequired = false;

  WeddingLifecycleService get _service =>
      widget.service ?? WeddingLifecycleService();

  Future<void> _archive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu trữ đám cưới?'),
        content: const Text(
          'Dữ liệu vẫn được giữ lại và có thể xem, nhưng đám cưới sẽ chuyển sang chỉ đọc. '
          'Thiệp công khai và RSVP sẽ không còn khả dụng. Phiên bản MVP không hỗ trợ khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-archive'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.archiveWedding(widget.weddingId);
      if (mounted) widget.onArchived();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu trữ đám cưới. Vui lòng thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDeleteConfirmation() async {
    var matches = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Xóa vĩnh viễn đám cưới?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thao tác này không thể hoàn tác và sẽ xóa dữ liệu thuộc đám cưới.',
              ),
              const SizedBox(height: 16),
              Text('Nhập chính xác tên: ${widget.weddingName}'),
              const SizedBox(height: 8),
              TextField(
                key: const Key('delete-name-input'),
                autofocus: true,
                onChanged: (value) => setDialogState(
                  () => matches = weddingNamesMatch(widget.weddingName, value),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const Key('confirm-delete'),
              onPressed: matches ? () => Navigator.pop(context, true) : null,
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Xóa vĩnh viễn'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) await _delete();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _retryRequired = false;
    });
    final result = await _service.deleteWedding(widget.weddingId);
    if (!mounted) return;
    if (result == WeddingDeleteResult.deleted) {
      await widget.onDeleted();
      return;
    }
    setState(() {
      _busy = false;
      _retryRequired = result == WeddingDeleteResult.retryRequired ||
          result == WeddingDeleteResult.failed;
    });
    final message = result == WeddingDeleteResult.unauthorized
        ? 'Bạn không có quyền thực hiện thao tác này.'
        : 'Quá trình xóa chưa hoàn tất. Bạn có thể thử lại.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == 'DELETING') {
      return _buildDeletingState();
    }
    final archived = widget.status == 'ARCHIVED';
    if (!widget.isOwner && !archived) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (archived ? Colors.amber : Colors.redAccent).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (archived ? Colors.amber : Colors.redAccent).withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (archived) ...[
            const Text(
              'ARCHIVED · CHỈ ĐỌC',
              key: Key('archived-badge'),
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dữ liệu vẫn có thể xem. Các thao tác chỉnh sửa và thiệp công khai đã bị khóa.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
          if (widget.isOwner) ...[
            if (!archived)
              OutlinedButton.icon(
                key: const Key('archive-action'),
                onPressed: _busy ? null : _archive,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Lưu trữ đám cưới'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('delete-action'),
              onPressed: _busy ? null : _openDeleteConfirmation,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Xóa đám cưới vĩnh viễn'),
            ),
          ],
          if (archived)
            TextButton(
              key: const Key('switch-archived-wedding'),
              onPressed: widget.onSwitchWedding,
              child: const Text('Chuyển đám cưới'),
            ),
        ],
      ),
    );
  }

  Widget _buildDeletingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              const CircularProgressIndicator()
            else
              const Icon(Icons.hourglass_top_rounded, size: 56, color: Colors.amber),
            const SizedBox(height: 18),
            const Text(
              'Đang xóa đám cưới…',
              key: Key('deleting-state'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _retryRequired
                  ? 'Quá trình xóa chưa hoàn tất. Bạn có thể thử lại.'
                  : 'Không đóng ứng dụng nếu bạn đang tiếp tục quá trình xóa.',
              textAlign: TextAlign.center,
            ),
            if (widget.isOwner) ...[
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('retry-delete'),
                onPressed: _busy ? null : _delete,
                child: const Text('Thử lại'),
              ),
            ],
            TextButton(
              key: const Key('switch-wedding'),
              onPressed: widget.onSwitchWedding,
              child: const Text('Chuyển đám cưới'),
            ),
          ],
        ),
      ),
    );
  }
}
