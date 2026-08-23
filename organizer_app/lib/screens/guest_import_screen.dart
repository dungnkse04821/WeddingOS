import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/guest_import_model.dart';
import '../models/guest_model.dart';
import '../services/guest_import_service.dart';
import '../services/supabase_service.dart';

class GuestImportScreen extends StatefulWidget {
  final String weddingId;
  final List<GuestModel> existingGuests;

  const GuestImportScreen({
    super.key,
    required this.weddingId,
    required this.existingGuests,
  });

  @override
  State<GuestImportScreen> createState() => _GuestImportScreenState();
}

class _GuestImportScreenState extends State<GuestImportScreen> {
  final GuestImportService _importService = GuestImportService();
  final GuestImportFilePicker _filePicker = GuestImportFilePicker();

  GuestImportPreview? _preview;
  GuestImportStatus? _filter;
  bool _loading = false;
  bool _confirming = false;
  bool _warningsAcknowledged = false;
  String? _requestId;
  String? _message;

  Future<void> _downloadTemplate() async {
    final file = await _importService.writeTemplateToDownloads();
    if (!mounted) return;
    setState(() {
      _message = 'Đã tạo template mẫu tại: ${file.path}';
    });
  }

  Future<void> _pickAndParse() async {
    setState(() {
      _loading = true;
      _message = null;
      _preview = null;
      _warningsAcknowledged = false;
      _requestId = null;
    });

    try {
      final Uint8List? bytes = await _filePicker.pickXlsxBytes();
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _loading = false);
        return;
      }

      final preview = _importService.parseXlsxBytes(
        bytes: bytes,
        existingGuests: widget.existingGuests,
      );
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Không thể đọc tệp .xlsx. Vui lòng dùng đúng template WeddingOS và thử lại.';
      });
    }
  }

  Future<void> _confirmImport() async {
    final preview = _preview;
    if (preview == null || preview.hasFatalRows || _confirming) return;
    if (preview.warningRows > 0 && !_warningsAcknowledged) {
      setState(() {
        _message = 'Vui lòng xác nhận đã xem các cảnh báo trước khi nhập.';
      });
      return;
    }

    setState(() {
      _confirming = true;
      _message = null;
      _requestId ??= const Uuid().v4();
    });

    try {
      final result = await SupabaseService.instance.confirmGuestImport(
        requestId: _requestId!,
        weddingId: widget.weddingId,
        rows: preview.toConfirmRows(),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _message =
            'Không thể xác nhận import. Vui lòng kiểm tra kết nối và thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final rows = preview == null
        ? const <GuestImportRow>[]
        : _filter == null
        ? preview.rows
        : preview.rows.where((row) => row.status == _filter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF101420),
      appBar: AppBar(
        title: const Text(
          'Nhập Excel khách mời',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(preview),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              ),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00C6FF)),
                ),
              )
            else if (preview == null)
              Expanded(child: _buildEmptyState())
            else
              Expanded(child: _buildRows(rows)),
          ],
        ),
      ),
      bottomNavigationBar: preview == null ? null : _buildConfirmBar(preview),
    );
  }

  Widget _buildHeader(GuestImportPreview? preview) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF102A43), Color(0xFF1B4332)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Template WeddingOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Party Key là khóa duy nhất để gom nhóm mời. Bỏ trống Party Key nghĩa là khách lẻ, không tự tạo Party.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _downloadTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Tạo template .xlsx'),
                ),
                ElevatedButton.icon(
                  onPressed: _pickAndParse,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Chọn tệp .xlsx'),
                ),
              ],
            ),
            if (preview != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summaryChip('Tổng', preview.totalRows, null),
                  _summaryChip(
                    'Valid',
                    preview.validRows,
                    GuestImportStatus.valid,
                  ),
                  _summaryChip(
                    'Warning',
                    preview.warningRows,
                    GuestImportStatus.warning,
                  ),
                  _summaryChip(
                    'Mapping',
                    preview.mappingRequiredRows,
                    GuestImportStatus.mappingRequired,
                  ),
                  _summaryChip(
                    'Error',
                    preview.errorRows,
                    GuestImportStatus.error,
                  ),
                  _plainChip('Party mới: ${preview.newParties}'),
                  _plainChip('Group có thể tạo: ${preview.newGroups}'),
                  _plainChip('Parse: ${preview.parseMilliseconds}ms'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, int count, GuestImportStatus? status) {
    return FilterChip(
      label: Text('$label: $count'),
      selected: _filter == status,
      onSelected: (_) => setState(() => _filter = status),
    );
  }

  Widget _plainChip(String label) {
    return Chip(label: Text(label));
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Chọn template .xlsx đã điền để xem Preview. Tệp gốc chỉ được đọc trên thiết bị và không được upload.',
          style: TextStyle(color: Colors.white60),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildRows(List<GuestImportRow> rows) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: rows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _rowCard(rows[index]),
    );
  }

  Widget _rowCard(GuestImportRow row) {
    final color = switch (row.status) {
      GuestImportStatus.valid => const Color(0xFF2DD4BF),
      GuestImportStatus.warning => Colors.orangeAccent,
      GuestImportStatus.mappingRequired => const Color(0xFFFACC15),
      GuestImportStatus.error => Colors.redAccent,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Dòng ${row.rowNumber}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.guestName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                row.status.name.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'SĐT: ${row.phone.isEmpty ? "Trống" : row.phone} | Email: ${row.email.isEmpty ? "Trống" : row.email}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            'Side: ${row.side} | Source: ${row.guestSource} | Group: ${row.primaryGroupName.isEmpty ? "NONE" : row.primaryGroupName}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            'Party Key: ${row.partyKey.isEmpty ? "NONE" : row.partyKey} | Party: ${row.partyDisplayName.isEmpty ? "NONE" : row.partyDisplayName} | Invited Count: ${row.invitedCount ?? "NONE"}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          for (final warning in row.warnings)
            Text(
              '• $warning',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          for (final error in row.errors)
            Text(
              '• $error',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmBar(GuestImportPreview preview) {
    final disabled = preview.hasFatalRows || _confirming;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1120),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (preview.warningRows > 0)
            CheckboxListTile(
              value: _warningsAcknowledged,
              onChanged: (value) =>
                  setState(() => _warningsAcknowledged = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Tôi đã xem cảnh báo trùng lặp và vẫn muốn nhập.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: disabled ? null : _confirmImport,
              icon: _confirming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(
                preview.hasFatalRows
                    ? 'Cần xử lý lỗi trước khi nhập'
                    : 'Xác nhận nhập danh sách',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
