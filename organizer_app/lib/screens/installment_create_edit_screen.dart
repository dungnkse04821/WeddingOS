
import 'package:flutter/material.dart';
import 'payment_refund_create_edit_screen.dart';

class InstallmentCreateEditScreen extends StatelessWidget {
  const InstallmentCreateEditScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết Thanh toán định kỳ")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Số tiền')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // FIN-007 Preview logic
              },
              child: const Text("Xem trước & Lưu thay đổi (FIN-007)"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentRefundCreateEditScreen()));
              },
              child: const Text("Tạo Thanh toán/Hoàn tiền"),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Xóa (Chỉ khi chưa có lịch sử)"),
            )
          ],
        ),
      ),
    );
  }
}
