import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class VietQrConfigurationScreen extends StatefulWidget {
  const VietQrConfigurationScreen({super.key, required this.wedding});

  final Map<String, dynamic> wedding;

  @override
  State<VietQrConfigurationScreen> createState() => _VietQrConfigurationScreenState();
}

class _VietQrConfigurationScreenState extends State<VietQrConfigurationScreen> {
  late bool _enabled;
  late final TextEditingController _bankId;
  late final TextEditingController _accountNumber;
  late final TextEditingController _accountName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _enabled = widget.wedding['vietqr_enabled'] as bool? ?? false;
    _bankId = TextEditingController(text: widget.wedding['vietqr_bank_id'] as String? ?? '');
    _accountNumber = TextEditingController(text: widget.wedding['vietqr_account_no'] as String? ?? '');
    _accountName = TextEditingController(text: widget.wedding['vietqr_account_name'] as String? ?? '');
  }

  @override
  void dispose() {
    _bankId.dispose();
    _accountNumber.dispose();
    _accountName.dispose();
    super.dispose();
  }

  bool get _isValid => !_enabled || (_bankId.text.trim().isNotEmpty && _accountNumber.text.trim().isNotEmpty && _accountName.text.trim().isNotEmpty);

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_isValid) {
      setState(() => _error = 'Khi bật VietQR, vui lòng nhập ngân hàng, số tài khoản và tên hiển thị.');
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.updateVietQrConfiguration(
        weddingId: widget.wedding['id'] as String,
        enabled: _enabled,
        bankId: _bankId.text,
        accountNumber: _accountNumber.text,
        accountName: _accountName.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể cập nhật VietQR lúc này. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cấu hình VietQR')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Thông tin này chỉ được hiển thị khi khách đã hoàn tất RSVP cho thiệp có sự kiện ngày chính xác.'),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Bật mừng cưới VietQR'),
            value: _enabled,
            onChanged: _saving ? null : (value) => setState(() => _enabled = value),
          ),
          TextField(controller: _bankId, enabled: !_saving, decoration: const InputDecoration(labelText: 'Ngân hàng (ví dụ: VCB)')),
          TextField(controller: _accountNumber, enabled: !_saving, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số tài khoản công khai')),
          TextField(controller: _accountName, enabled: !_saving, decoration: const InputDecoration(labelText: 'Tên chủ tài khoản hiển thị')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Đang lưu...' : 'Lưu cấu hình')),
          const SizedBox(height: 12),
          const Text('M4.3 không tải ảnh QR hoặc theo dõi thanh toán. Thông tin ngân hàng được hiển thị như một lựa chọn tùy tâm.', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
