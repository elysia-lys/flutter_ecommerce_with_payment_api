import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/mainpage.dart';
import 'history_content.dart'; // Displays full order and product details

/// Displays a list of all previously paid purchases for the logged-in user.
/// 
/// This page fetches transaction history from Firestore’s `paidProducts` collection.
/// Each list item navigates to a detailed order page (`HistoryContentPage`) when tapped.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// Stores the Firestore document ID of the currently logged-in user.
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchLoggedInUserId();
  }

  /// Retrieves the currently logged-in user's Firestore document ID.
  ///
  /// This method queries the `users` collection for any user
  /// with a `loggedIn` flag set to `true`. If found, the user ID
  /// is stored in `_userId` for subsequent Firestore queries.
  Future<void> _fetchLoggedInUserId() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();

      // Filter to find the first user document where 'loggedIn' == true
      final docs =
          snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() {
          _userId = loggedInUser.id;
        });
      } else {
        debugPrint("⚠️ No user is currently logged in.");
      }
    } catch (e) {
      debugPrint("🔥 Error fetching logged-in user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching user ID
    if (_userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    // Firestore reference: Get all paid products for the logged-in user
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
          /// Close button to return to the main page and clear navigation history
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

      /// Real-time listener for changes in the user's paid products collection
      body: StreamBuilder<QuerySnapshot>(
        stream: paidProductsRef.snapshots(),
        builder: (context, snapshot) {
          // Show progress indicator while waiting for Firestore response
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            );
          }

          // Show message if no paid transactions exist
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No paid products yet.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          // Extract paid transaction documents
          final paidProducts = snapshot.data!.docs;

          // Build scrollable list of paid purchases
          return ListView.builder(
            itemCount: paidProducts.length,
            itemBuilder: (context, index) {
              final doc = paidProducts[index];
              final data = doc.data() as Map<String, dynamic>;

              final txId = data['txId'] ?? '-';
              final orderId = data['orderId'] ?? '-';
              final productAmount = data['product']?['amount'] ?? '5.00';

              return Card(
                color: Colors.grey[900],
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  /// Displays key transaction info
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
                    ],
                  ),

                  /// Forward icon to indicate navigation
                  trailing: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white70, size: 18),

                  /// Navigate to order details page
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            HistoryContentPage(orderId: orderId),
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
