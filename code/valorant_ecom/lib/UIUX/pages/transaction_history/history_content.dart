import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Displays simplified order details for a given Firestore document ID in `paidProducts`.
class HistoryContentPage extends StatefulWidget {
  final String docId; // Firestore document ID from paidProducts

  const HistoryContentPage({
    super.key,
    required this.docId,
  });

  @override
  State<HistoryContentPage> createState() => _HistoryContentPageState();
}

class _HistoryContentPageState extends State<HistoryContentPage> {
  Map<String, dynamic>? orderData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

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

    // Normalize product list
    final productField = orderData?['product'];
    final productList = <Map<String, dynamic>>[];

    if (productField != null) {
      if (productField is List) {
        productList.addAll(List<Map<String, dynamic>>.from(productField));
      } else if (productField is Map) {
        productList.add(Map<String, dynamic>.from(productField));
      }
    }

    final custName = orderData?['custName'] ?? '-';
    final address = orderData?['address'] ?? '-';
    final email = orderData?['custEmail'] ?? '-';
    final number = orderData?['custContact'] ?? '-';
    final txId = orderData?['txId'] ?? '-';
    final orderId = orderData?['orderId'] ?? '-';
    final paymentMethod = orderData?['paymentMethod'] ?? '-';
    final deliveryStatus = orderData?['deliveryStatus'] ?? '-';

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
            // Order IDs
            Text(
              "Order ID: $orderId",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text("Transaction ID: $txId",
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),

            // Customer info
            const Text("Customer Info",
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Text("Name: $custName", style: const TextStyle(color: Colors.white70)),
            Text("Email: $email", style: const TextStyle(color: Colors.white70)),
            Text("Phone: $number", style: const TextStyle(color: Colors.white70)),
            Text("Address: $address", style: const TextStyle(color: Colors.white70)),
            const Divider(height: 32, color: Colors.white24),

            // Payment & Delivery info
            Text("Payment Method: $paymentMethod",
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            Text("Delivery Status: $deliveryStatus",
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const Divider(height: 32, color: Colors.white24),

            // Product list
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
            // ✅ Show button only if status is "delivering"
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
