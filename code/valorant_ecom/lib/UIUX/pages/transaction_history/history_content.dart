import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Displays detailed order information for a given `orderId`.
///
/// This page retrieves order data from Firestore and shows all relevant details:
/// - Transaction information (Order ID, Tx ID, payment method)
/// - Customer details
/// - Product list
/// - Payment and delivery statuses
///
/// The user can also mark the order as "Received," which updates the delivery
/// status to "Completed" in Firestore.
class HistoryContentPage extends StatefulWidget {
  /// The Firestore document ID representing this order.
  final String orderId;

  const HistoryContentPage({
    super.key,
    required this.orderId,
  });

  @override
  State<HistoryContentPage> createState() => _HistoryContentPageState();
}

class _HistoryContentPageState extends State<HistoryContentPage> {
  /// Holds the loaded order document data from Firestore.
  Map<String, dynamic>? orderData;

  /// Used to show a loading indicator while the order is being fetched.
  bool isLoading = true;

  /// Tracks whether the user has confirmed receiving the order.
  bool orderReceived = false;

  @override
  void initState() {
    super.initState();
    _fetchOrder(); // Begin fetching order details on page initialization.
  }

  /// 🔹 Fetches the order document from Firestore using the provided `orderId`.
  ///
  /// On success, assigns the retrieved data to `orderData` and hides the loading spinner.
  /// If the document is missing or an error occurs, logs the issue and stops loading.
  Future<void> _fetchOrder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (doc.exists) {
        setState(() {
          orderData = doc.data();
          isLoading = false;
        });
      } else {
        debugPrint("⚠️ Order not found: ${widget.orderId}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching order: $e");
      setState(() => isLoading = false);
    }
  }

  /// 🔹 Marks the current order as received.
  ///
  /// Updates the Firestore document to set `deliveryStatus` = "Completed".
  /// Also updates local UI state to immediately reflect the change.
  Future<void> markOrderReceived() async {
    if (orderData == null) return;

    final orderRef =
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    await orderRef.update({'deliveryStatus': 'Completed'});

    setState(() {
      orderReceived = true;
      orderData!['deliveryStatus'] = 'Completed';
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Display loading indicator while Firestore data is being fetched.
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    // 🔹 Display fallback UI when order cannot be found.
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

    // Extract relevant order details safely from Firestore data.
    final productList =
        List<Map<String, dynamic>>.from(orderData?['productList'] ?? []);
    final custName = orderData?['custName'] ?? '-';
    final address = orderData?['address'] ?? '-';
    final email = orderData?['custEmail'] ?? '-';
    final number = orderData?['custContact'] ?? '-';
    final txAmount = orderData?['txAmount'] ?? 0.0;
    final txId = orderData?['txId'] ?? '-';
    final txChannel = orderData?['txChannel'] ?? '-';
    final paymentStatus = orderData?['status'] ?? 'Pending';
    final deliveryStatus = orderData?['deliveryStatus'] ?? 'Pending';

    // Convert internal payment channel codes into readable payment methods.
    String paymentMedium;
    switch (txChannel) {
      case 'DD':
        paymentMedium = 'Online Banking';
      case 'CC':
        paymentMedium = 'Credit Card';
      case 'EW':
        paymentMedium = 'E-Wallet';
      default:
        paymentMedium = 'Unknown';
    }

    // 🔹 Build main order details UI
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
            // 🔸 Order ID & Transaction ID section
            Text(
              "Order ID: ${widget.orderId}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              "Transaction ID: $txId",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // 🔸 Customer information section
            const Text(
              "Customer Info",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text("Name: $custName",
                style: const TextStyle(color: Colors.white70)),
            Text("Email: $email",
                style: const TextStyle(color: Colors.white70)),
            Text("Phone: $number",
                style: const TextStyle(color: Colors.white70)),
            Text("Address: $address",
                style: const TextStyle(color: Colors.white70)),
            const Divider(height: 32, color: Colors.white24),

            // 🔸 Payment information section
            Text(
              "Payment Method: $paymentMedium",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              "Total Paid: RM${double.tryParse(txAmount.toString())?.toStringAsFixed(2) ?? '5.00'}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              "Payment Status: $paymentStatus",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              "Delivery Status: $deliveryStatus",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Divider(height: 32, color: Colors.white24),

            // 🔸 Product list section
            const Text(
              "Products",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Display each purchased product
            if (productList.isNotEmpty)
              ...productList.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    "Product ID: ${item['id'] ?? '-'} | Name: ${item['name'] ?? '-'} | Qty: ${item['qty']} | RM ${double.tryParse(item['amount'].toString())?.toStringAsFixed(2) ?? '5.00'}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              const Text(
                "No items found.",
                style: TextStyle(color: Colors.white70),
              ),

            const SizedBox(height: 20),

            // 🔸 Mark order as received button
            if (!orderReceived && deliveryStatus != 'Completed')
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text("Order Received"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: markOrderReceived,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
