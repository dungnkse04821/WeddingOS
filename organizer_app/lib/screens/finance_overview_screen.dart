import 'package:flutter/material.dart';
import '../models/finance_summary_model.dart';
import '../services/finance_service.dart';
import '../services/supabase_service.dart';
import 'budget_item_list_screen.dart';

class FinanceOverviewScreen extends StatefulWidget {
  final FinanceService? financeService;
  final SupabaseService? supabaseService;

  const FinanceOverviewScreen({
    Key? key,
    this.financeService,
    this.supabaseService,
  }) : super(key: key);

  @override
  State<FinanceOverviewScreen> createState() => _FinanceOverviewScreenState();
}

class _FinanceOverviewScreenState extends State<FinanceOverviewScreen> {
  bool _loading = true;
  String? _error;
  FinanceSummaryModel? _summary;

  FinanceService get _financeService => widget.financeService ?? FinanceService.instance;
  SupabaseService get _supabaseService => widget.supabaseService ?? SupabaseService.instance;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final weddingId = _supabaseService.getSelectedWeddingId();
      if (weddingId == null) throw Exception("No wedding selected");
      final summary = await _financeService.fetchFinanceSummary(weddingId);
      setState(() {
        _summary = summary;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tổng quan Tài chính"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSummary,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error"))
              : _summary == null
                  ? const Center(child: Text("Không có dữ liệu tài chính."))
                  : _buildSummaryView(),
    );
  }

  Widget _buildSummaryView() {
    final s = _summary!;
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCard("Dự kiến tổng", s.totalProjected, Colors.blue),
          _buildCard("Đã xác nhận", s.totalConfirmed, Colors.blueAccent),
          _buildCard("Đã thanh toán (net)", s.netPaid, Colors.green),
          _buildCard("Còn nợ", s.outstanding == null ? "Không xác định" : s.outstanding!, s.outstanding == null ? Colors.grey : Colors.orange),
          _buildCard("Trả dư", s.overpaid, Colors.red),
          _buildCard("Sắp tới (7 ngày)", s.upcoming7d, Colors.amber),
          _buildCard("Sắp tới (30 ngày)", s.upcoming30d, Colors.amber.shade700),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetItemListScreen()),
              ).then((_) => _loadSummary());
            },
            child: const Text("Quản lý Hạng mục"),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
