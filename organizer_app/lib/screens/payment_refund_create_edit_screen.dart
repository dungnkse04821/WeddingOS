
import 'package:flutter/material.dart';

class PaymentRefundCreateEditScreen extends StatelessWidget {
  const PaymentRefundCreateEditScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tạo/Sửa Thanh Toán")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Số tiền')),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Loại Payer'),
              items: const [
                DropdownMenuItem(value: 'MEMBER', child: Text('Thành viên trong ban tổ chức')),
                DropdownMenuItem(value: 'EXTERNAL', child: Text('Nhập tên tự do (Bố cô dâu...)')),
              ],
              onChanged: (val) {},
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Bên chi trả (Cost Side)'),
              items: const [
                DropdownMenuItem(value: 'COMMON', child: Text('Chung')),
                DropdownMenuItem(value: 'BRIDE_SIDE', child: Text('Nhà gái')),
                DropdownMenuItem(value: 'GROOM_SIDE', child: Text('Nhà trai')),
              ],
              onChanged: (val) {},
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Lưu Biên lai (FIN-001/004)"),
            )
          ],
        ),
      ),
    );
  }
}
