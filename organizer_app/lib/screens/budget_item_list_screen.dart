import 'package:flutter/material.dart';
import '../models/budget_item_model.dart';
import '../services/finance_service.dart';
import '../services/supabase_service.dart';
import 'budget_item_create_edit_screen.dart';
import 'installment_create_edit_screen.dart';
import 'payment_refund_create_edit_screen.dart';

class BudgetItemListScreen extends StatefulWidget {
  const BudgetItemListScreen({Key? key}) : super(key: key);

  @override
  State<BudgetItemListScreen> createState() => _BudgetItemListScreenState();
}

class _BudgetItemListScreenState extends State<BudgetItemListScreen> {
  bool _loading = true;
  String? _error;
  List<BudgetItemModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final weddingId = SupabaseService.instance.getSelectedWeddingId();
      if (weddingId == null) throw Exception("No wedding selected");
      final items = await FinanceService.instance.listBudgetItems(weddingId);
      setState(() {
        _items = items;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await FinanceService.instance.deleteBudgetItem(id);
      _loadItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hạng mục Tài chính"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadItems,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ExpansionTile(
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Dự kiến: ${item.estimatedCost ?? '0.00'} | Xác nhận: ${item.confirmedCost ?? '0.00'}"),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => BudgetItemCreateEditScreen(item: item))).then((_) => _loadItems());
                                },
                                child: const Text("Sửa hạng mục"),
                              ),
                              TextButton(
                                onPressed: () => _deleteItem(item.id),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text("Xoá"),
                              ),
                            ],
                          ),
                          const Divider(),
                          Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => InstallmentCreateEditScreen(budgetItemId: item.id))).then((_) => _loadItems());
                                },
                                child: const Text("+ Đợt chi"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentRefundCreateEditScreen(budgetItemId: item.id, isRefund: false))).then((_) => _loadItems());
                                },
                                child: const Text("+ Thanh toán"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentRefundCreateEditScreen(budgetItemId: item.id, isRefund: true))).then((_) => _loadItems());
                                },
                                child: const Text("+ Hoàn tiền"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetItemCreateEditScreen())).then((_) => _loadItems());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
