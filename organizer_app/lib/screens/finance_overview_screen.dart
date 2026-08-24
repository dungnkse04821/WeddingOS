
import 'package:flutter/material.dart';
import 'budget_item_list_screen.dart';

class FinanceOverviewScreen extends StatelessWidget {
  const FinanceOverviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tổng quan Tài chính")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Không xác định"), // For unknown semantics
            const SizedBox(height: 16),
            ElevatedButton(
              onPath: () {},
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BudgetItemListScreen()),
                );
              },
              child: const Text("Quản lý Hạng mục"),
            ),
          ],
        ),
      ),
    );
  }
}
