import 'package:flutter/material.dart';
import '../models/installment_model.dart';
import '../services/finance_service.dart';

class InstallmentCreateEditScreen extends StatefulWidget {
  final String budgetItemId;
  final InstallmentModel? item;

  const InstallmentCreateEditScreen({Key? key, required this.budgetItemId, this.item}) : super(key: key);

  @override
  State<InstallmentCreateEditScreen> createState() => _InstallmentCreateEditScreenState();
}

class _InstallmentCreateEditScreenState extends State<InstallmentCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  DateTime _dueDate = DateTime.now();
  bool _loading = false;
  Map<String, dynamic>? _preview;
  String? _amountToCommit;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.item?.amount ?? '');
    if (widget.item != null) {
      _dueDate = widget.item!.dueDate;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (widget.item == null) {
        await FinanceService.instance.createInstallment({
          'budget_item_id': widget.budgetItemId,
          'amount': double.parse(_amountCtrl.text),
          'due_date': _dueDate.toIso8601String().split('T').first,
        });
        if (mounted) Navigator.pop(context);
      } else {
        // Edit logic -> FIN-007 Preview
        final preview = await FinanceService.instance.previewInstallmentCompound(
          widget.item!.id,
          _amountCtrl.text,
          _dueDate.toIso8601String().split('T').first,
        );
        setState(() {
          _preview = preview;
          _amountToCommit = _amountCtrl.text;
          _loading = false;
        });
        return; // Don't pop yet
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted && widget.item == null) setState(() => _loading = false);
    }
  }

  Future<void> _commit() async {
    if (_preview == null || _amountToCommit == null) return;
    setState(() => _loading = true);
    try {
      final fingerprint = _preview!['impact_fingerprint'] as String;
      await FinanceService.instance.commitInstallmentCompound(
        widget.item!.id,
        fingerprint,
        _amountToCommit!,
        _dueDate.toIso8601String().split('T').first,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_preview != null) {
      final warnings = _preview!['warnings'] as List<dynamic>? ?? [];
      return Scaffold(
        appBar: AppBar(title: const Text("Xác nhận thay đổi")),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text("Sự thay đổi này ảnh hưởng đến các khoản thanh toán hiện tại.", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (warnings.isNotEmpty)
                    Container(
                      color: Colors.amber.shade100,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: warnings.map((w) => Text("⚠️ ${w['code']}: ${w['details']}", style: const TextStyle(color: Colors.deepOrange))).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _commit,
                    child: const Text("Xác nhận thay đổi (FIN-007)"),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _preview = null),
                    child: const Text("Huỷ"),
                  )
                ],
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? "Thêm đợt chi" : "Sửa đợt chi")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: "Số tiền"),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v!.isEmpty ? "Bắt buộc nhập" : null,
                  ),
                  ListTile(
                    title: const Text("Ngày đến hạn"),
                    subtitle: Text(_dueDate.toIso8601String().split('T').first),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _dueDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text("Lưu"),
                  ),
                ],
              ),
            ),
    );
  }
}
