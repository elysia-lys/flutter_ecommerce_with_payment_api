// ==============================
// HISTORY_CONTENT.DART
// Displays details of a specific paid order
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ==============================
// HISTORY CONTENT PAGE WIDGET
// ==============================

/// A page that displays detailed information for a single order
/// fetched from Firestore `paidProducts` collection.
/// 
/// - [docId] is the Firestore document ID of the order.
/// - Displays customer info, products, payment info, and delivery status.
/// - Allows marking order as "Completed" if currently "delivering".
class HistoryContentPage extends StatefulWidget {
  /// Firestore document ID for the specific order
  final String docId;

  const HistoryContentPage({
    super.key,
    required this.docId,
  });

  @override
  State<HistoryContentPage> createState() => _HistoryContentPageState();
}

// ==============================
// HISTORY CONTENT STATE
// ==============================

class _HistoryContentPageState extends State<HistoryContentPage> {
  /// Stores fetched order data
  Map<String, dynamic>? orderData;

  /// Indicates if Firestore fetch is in progress
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrder(); // Load order details on page load
  }

  // ==============================
  // FETCH ORDER DATA FROM FIRESTORE
  // ==============================

  /// Retrieves the order document from Firestore.
  /// 
  /// Steps:
  /// 1. Access `paidProducts` collection using `docId`.
  /// 2. If document exists, store its data in [orderData].
  /// 3. Handle errors and log missing documents.
  Future<void> _fetchOrder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('paidProducts')
          .doc(widget.docId)
          .get();

      if (doc.exists) {
        setState(() {
          orderData = doc.data();
          isLoading = false;
        });
      } else {
        debugPrint("⚠️ Order not found: ${widget.docId}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching order: $e");
      setState(() => isLoading = false);
    }
  }

  // ==============================
  // MARK ORDER AS COMPLETED
  // ==============================

  /// Updates the `deliveryStatus` of the order to "Completed".
  /// 
  /// Updates Firestore and refreshes UI state.
  Future<void> markOrderCompleted() async {
    if (orderData == null) return;

    final orderRef = FirebaseFirestore.instance
        .collection('paidProducts')
        .doc(widget.docId);

    await orderRef.update({'deliveryStatus': 'Completed'});

    setState(() {
      orderData!['deliveryStatus'] = 'Completed';
    });
  }

  // ==============================
  // BUILD METHOD
  // ==============================

  @override
  Widget build(BuildContext context) {
    // 🔹 Show loading spinner while fetching data
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    // ⚠️ Handle case where order was not found
    if (orderData == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "Order not found.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // ==============================
    // NORMALIZE PRODUCT DATA
    // ==============================
    final productField = orderData?['product'];
    final productList = <Map<String, dynamic>>[];

    if (productField != null) {
      if (productField is List) {
        productList.addAll(List<Map<String, dynamic>>.from(productField));
      } else if (productField is Map) {
        productList.add(Map<String, dynamic>.from(productField));
      }
    }

    // ==============================
    // EXTRACT ORDER FIELDS WITH FALLBACKS
    // ==============================
    final custName = orderData?['custName'] ?? '-';
    final address = orderData?['address'] ?? '-';
    final email = orderData?['custEmail'] ?? '-';
    final number = orderData?['custContact'] ?? '-';
    final txId = orderData?['txId'] ?? '-';
    final orderId = orderData?['orderId'] ?? '-';
    final paymentMethod = orderData?['paymentMethod'] ?? '-';
    final deliveryStatus = orderData?['deliveryStatus'] ?? '-';

    // ==============================
    // BUILD PAGE LAYOUT
    // ==============================
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Details"),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----- ORDER IDENTIFIERS -----
            Text(
              "Order ID: $orderId",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text("Transaction ID: $txId",
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),

            // ----- CUSTOMER INFO -----
            const Text("Customer Info",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Text("Name: $custName", style: const TextStyle(color: Colors.white70)),
            Text("Email: $email", style: const TextStyle(color: Colors.white70)),
            Text("Phone: $number", style: const TextStyle(color: Colors.white70)),
            Text("Address: $address", style: const TextStyle(color: Colors.white70)),
            const Divider(height: 32, color: Colors.white24),

            // ----- PAYMENT & DELIVERY INFO -----
            Text("Payment Method: $paymentMethod",
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            Text("Delivery Status: $deliveryStatus",
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const Divider(height: 32, color: Colors.white24),

            // ----- PRODUCT LIST -----
            const Text("Products",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            if (productList.isNotEmpty)
              ...productList.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                      "Name: ${item['name'] ?? '-'} | Qty: ${item['qty'] ?? 1} | RM ${item['amount'] ?? '0.00'}",
                      style: const TextStyle(color: Colors.white70)),
                ),
              )
            else
              const Text("No items found.", style: TextStyle(color: Colors.white70)),

            const SizedBox(height: 20),

            // ----- MARK ORDER AS COMPLETED BUTTON -----
            // ✅ Only show button if order is currently delivering
            if (deliveryStatus == 'delivering')
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text("Order Received"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: markOrderCompleted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
