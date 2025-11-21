import 'package:flutter/material.dart';
import 'admin_layout.dart';

class AdminOrderManagementPage extends StatelessWidget {
  const AdminOrderManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: "Order Management",
      body: const Center(
        child: Text(
          "Order Management Page",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
      ),
    );
  }
}
