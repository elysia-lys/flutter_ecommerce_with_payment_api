// ==============================
// HISTORY.DART
// Displays a logged-in user's purchase history
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/mainpage.dart'; // Main dashboard page
import 'history_content.dart'; // Detailed order view

// ==============================
// HISTORY PAGE WIDGET
// ==============================

/// A page showing the purchase history of the currently logged-in user.
/// 
/// Fetches the `userId` from Firestore by checking the `loggedIn` field.
/// Displays all orders from the `paidProducts` collection for that user.
/// Each item navigates to [HistoryContentPage] for full order details.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

// ==============================
// HISTORY PAGE STATE
// ==============================

class _HistoryPageState extends State<HistoryPage> {
  /// Stores the Firestore document ID of the logged-in user
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchLoggedInUserId(); // Determine the currently logged-in user
  }

  // ==============================
  // FETCH LOGGED-IN USER
  // ==============================

  /// Retrieves the currently logged-in user from Firestore.
  /// 
  /// Steps:
  /// 1. Query the `users` collection.
  /// 2. Filter documents where `loggedIn` == true.
  /// 3. Set [_userId] if a logged-in user exists.
  /// 4. Logs warnings if no user is logged in or if an error occurs.
  Future<void> _fetchLoggedInUserId() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() => _userId = loggedInUser.id);
      } else {
        debugPrint("⚠️ No user is currently logged in.");
      }
    } catch (e) {
      debugPrint("🔥 Error fetching logged-in user: $e");
    }
  }

  // ==============================
  // BUILD METHOD
  // ==============================

  @override
  Widget build(BuildContext context) {
    // 🔹 Show loading spinner while fetching user ID
    if (_userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    // Reference to paid products of the logged-in user
    final paidProductsRef = FirebaseFirestore.instance
        .collection('paidProducts')
        .where('userId', isEqualTo: _userId);

    // ==============================
    // PAGE LAYOUT
    // ==============================
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Remove default back button
        backgroundColor: Colors.redAccent,
        title: const Text("Purchase History"),
        centerTitle: true,
        actions: [
          // Close button navigates back to MainPage
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      // ==============================
      // DISPLAY ORDERS USING STREAMBUILDER
      // ==============================
      body: StreamBuilder<QuerySnapshot>(
        stream: paidProductsRef.snapshots(),
        builder: (context, snapshot) {
          // 🔹 Show loading spinner while Firestore data loads
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            );
          }

          // ⚠️ Handle empty order list
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No paid products yet.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final paidProducts = snapshot.data!.docs;

          // ==============================
          // LISTVIEW OF ORDERS
          // ==============================
          return ListView.builder(
            itemCount: paidProducts.length,
            itemBuilder: (context, index) {
              final doc = paidProducts[index];
              final data = doc.data() as Map<String, dynamic>;

              // Extract key fields with fallbacks
              final txId = data['txId'] ?? '-';
              final orderId = data['orderId'] ?? '-';
              final productAmount = data['product']?['amount'] ?? '0.00';
              final deliveryStatus = data['deliveryStatus'] ?? 'Pending';

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  // ----- ORDER INFO -----
                  title: Text(
                    "Order ID: $orderId",
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Transaction ID: $txId",
                          style: const TextStyle(color: Colors.white70)),
                      Text("Amount Paid: RM$productAmount",
                          style: const TextStyle(color: Colors.white70)),
                      // Delivery status color-coded
                      Text(
                        "Delivery Status: $deliveryStatus",
                        style: TextStyle(
                          color: deliveryStatus == 'Completed'
                              ? Colors.greenAccent
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white70, size: 18),
                  // Navigate to detailed order page
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoryContentPage(docId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
