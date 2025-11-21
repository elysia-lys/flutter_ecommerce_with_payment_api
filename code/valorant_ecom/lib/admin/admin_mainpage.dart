import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../UIUX/login_credential/login.dart';
import '../admin/admin_layout.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  bool _loading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString("loggedInUser");

      if (userId == null) {
        setState(() {
          _loading = false;
          _isLoggedIn = false;
        });
        return;
      }

      // Admin override
      if (userId == "admin_admin") {
        setState(() {
          _isLoggedIn = true;
          _loading = false;
        });
        return;
      }

      // Normal user check
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .get();

      setState(() {
        _isLoggedIn =
            userDoc.exists && userDoc.data()?["loggedIn"] == true;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Login check error: $e");
      setState(() {
        _loading = false;
        _isLoggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    if (!_isLoggedIn) {
      return const LoginPage();
    }

    return AdminLayout(
      title: "Admin Dashboard",
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            );
          }

          final now = DateTime.now();
          int todayOrders = 0, monthOrders = 0, yearOrders = 0;
          double todayEarned = 0, monthEarned = 0, yearEarned = 0;
          double totalEarned = 0;

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            // Only consider paid orders
            if (data['status'] != 'paid') continue;

            if (data['updatedAt'] == null || data['txAmount'] == null) continue;

            final updatedAt = (data['updatedAt'] as Timestamp).toDate();
            final txAmount = double.tryParse(data['txAmount'].toString()) ?? 0;

            totalEarned += txAmount; // All-time total

            if (updatedAt.year == now.year) {
              yearOrders++;
              yearEarned += txAmount;
              if (updatedAt.month == now.month) {
                monthOrders++;
                monthEarned += txAmount;
                if (updatedAt.day == now.day) {
                  todayOrders++;
                  todayEarned += txAmount;
                }
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatCard("Today's Orders", todayOrders, todayEarned),
                const SizedBox(height: 16),
                _buildStatCard("This Month", monthOrders, monthEarned),
                const SizedBox(height: 16),
                _buildStatCard("This Year", yearOrders, yearEarned),
                const SizedBox(height: 16),
                _buildStatCard("All-Time Earned", 0, totalEarned,
                    showOrders: false),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int orders, double earned,
      {bool showOrders = true}) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (showOrders)
                  Text("Orders: $orders",
                      style: const TextStyle(color: Colors.white70)),
              ],
            ),
            Text("RM ${earned.toStringAsFixed(2)}",
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
