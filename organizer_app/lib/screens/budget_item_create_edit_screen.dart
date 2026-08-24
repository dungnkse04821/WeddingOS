
import 'package:flutter/material.dart';
import 'installment_create_edit_screen.dart';

class BudgetItemCreateEditScreen extends StatelessWidget {
  const BudgetItemCreateEditScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tạo/Sửa Hạng mục")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Tên hạng mục')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const InstallmentCreateEditScreen()));
              },
              child: const Text("Quản lý Thanh toán định kỳ"),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Xóa Hạng mục (Chỉ khi chưa có lịch sử)"),
            )
          ],
        ),
      ),
    );
  }
}
