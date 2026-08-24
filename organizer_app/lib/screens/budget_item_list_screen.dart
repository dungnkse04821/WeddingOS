
import 'package:flutter/material.dart';
import 'budget_item_create_edit_screen.dart';

class BudgetItemListScreen extends StatelessWidget {
  const BudgetItemListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hạng mục Chi phí")),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Venue"),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetItemCreateEditScreen()));
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetItemCreateEditScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
