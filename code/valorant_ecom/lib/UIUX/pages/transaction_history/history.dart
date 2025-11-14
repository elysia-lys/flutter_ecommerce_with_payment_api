import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/mainpage.dart';
import 'history_content.dart'; // Displays full order and product details

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchLoggedInUserId();
  }

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

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    final paidProductsRef = FirebaseFirestore.instance
        .collection('paidProducts')
        .where('userId', isEqualTo: _userId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.redAccent,
        title: const Text("Purchase History"),
        centerTitle: true,
        actions: [
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
      body: StreamBuilder<QuerySnapshot>(
        stream: paidProductsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No paid products yet.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final paidProducts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: paidProducts.length,
            itemBuilder: (context, index) {
              final doc = paidProducts[index];
              final data = doc.data() as Map<String, dynamic>;

              final txId = data['txId'] ?? '-';
              final orderId = data['orderId'] ?? '-';
              final productAmount = data['product']?['amount'] ?? '5.00';
              final deliveryStatus = data['deliveryStatus'] ?? 'Pending';

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
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
                      // ✅ Delivery status displayed
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
                  // ✅ Pass Firestore doc ID instead of orderId
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
