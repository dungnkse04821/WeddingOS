import 'package:flutter/material.dart';
import '../services/finance_service.dart';

class PaymentRefundCreateEditScreen extends StatefulWidget {
  final String budgetItemId;
  final bool isRefund;

  const PaymentRefundCreateEditScreen({
    Key? key,
    required this.budgetItemId,
    required this.isRefund,
  }) : super(key: key);

  @override
  State<PaymentRefundCreateEditScreen> createState() => _PaymentRefundCreateEditScreenState();
}

class _PaymentRefundCreateEditScreenState extends State<PaymentRefundCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _nameCtrl; // Payer / Receiver
  late TextEditingController _notesCtrl;
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (widget.isRefund) {
        await FinanceService.instance.createRefund(
          budgetItemId: widget.budgetItemId,
          amount: _amountCtrl.text,
          refundDate: _date.toIso8601String().split('T').first,
          receiver: _nameCtrl.text,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        );
      } else {
        await FinanceService.instance.createPayment(
          budgetItemId: widget.budgetItemId,
          amount: _amountCtrl.text,
          paymentDate: _date.toIso8601String().split('T').first,
          payerDisplayName: _nameCtrl.text,
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isRefund ? "Thêm Hoàn tiền" : "Thêm Thanh toán")),
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
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(labelText: widget.isRefund ? "Người nhận" : "Người thanh toán"),
                    validator: (v) => v!.isEmpty ? "Bắt buộc nhập" : null,
                  ),
                  ListTile(
                    title: Text(widget.isRefund ? "Ngày hoàn" : "Ngày thanh toán"),
                    subtitle: Text(_date.toIso8601String().split('T').first),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                  ),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: "Ghi chú"),
                    maxLines: 3,
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
