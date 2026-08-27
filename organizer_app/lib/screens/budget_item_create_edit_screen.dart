import 'package:flutter/material.dart';

import '../models/budget_item_model.dart';
import '../services/finance_service.dart';
import '../services/supabase_service.dart';
import '../utils/money_text.dart';

class BudgetItemCreateEditScreen extends StatefulWidget {
  final BudgetItemModel? item;

  const BudgetItemCreateEditScreen({Key? key, this.item}) : super(key: key);

  @override
  State<BudgetItemCreateEditScreen> createState() =>
      _BudgetItemCreateEditScreenState();
}

class _BudgetItemCreateEditScreenState
    extends State<BudgetItemCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _estCostCtrl;
  late TextEditingController _confCostCtrl;
  String _side = 'COMMON';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    _estCostCtrl = TextEditingController(
      text: widget.item?.estimatedCost ?? '',
    );
    _confCostCtrl = TextEditingController(
      text: widget.item?.confirmedCost ?? '',
    );
    if (widget.item != null) {
      _side = widget.item!.side;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _estCostCtrl.dispose();
    _confCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final data = {
        'wedding_id': SupabaseService.instance.getSelectedWeddingId(),
        'name': _nameCtrl.text,
        'estimated_cost': MoneyText.normalizeOptional(
          _estCostCtrl.text,
          allowZero: true,
        ),
        'confirmed_cost': MoneyText.normalizeOptional(
          _confCostCtrl.text,
          allowZero: true,
        ),
        'side': _side,
      };

      if (widget.item == null) {
        await FinanceService.instance.createBudgetItem(data);
      } else {
        await FinanceService.instance.updateBudgetItem(widget.item!.id, data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final failure = await SupabaseService.instance.handleOperationalError(e);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? "Thêm Hạng mục" : "Sửa Hạng mục"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Tên hạng mục",
                    ),
                    validator: (v) => v!.isEmpty ? "Bắt buộc nhập" : null,
                  ),
                  TextFormField(
                    controller: _estCostCtrl,
                    decoration: const InputDecoration(
                      labelText: "Chi phí dự kiến",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => MoneyText.validate(
                      value,
                      allowZero: true,
                      optional: true,
                    ),
                  ),
                  TextFormField(
                    controller: _confCostCtrl,
                    decoration: const InputDecoration(
                      labelText: "Chi phí xác nhận",
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => MoneyText.validate(
                      value,
                      allowZero: true,
                      optional: true,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _side,
                    items: const [
                      DropdownMenuItem(value: 'COMMON', child: Text("Chung")),
                      DropdownMenuItem(
                        value: 'BRIDE_SIDE',
                        child: Text("Nhà gái"),
                      ),
                      DropdownMenuItem(
                        value: 'GROOM_SIDE',
                        child: Text("Nhà trai"),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _side = v);
                    },
                    decoration: const InputDecoration(labelText: "Bên chi trả"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _submit, child: const Text("Lưu")),
                ],
              ),
            ),
    );
  }
}
