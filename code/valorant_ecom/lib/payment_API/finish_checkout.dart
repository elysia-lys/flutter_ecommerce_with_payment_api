import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A post-checkout confirmation screen that displays transaction results,
/// handles order cleanup, and updates Firestore collections accordingly.
///
/// This page is invoked after a payment attempt — whether successful or failed.
/// It retrieves the related order from Firestore and either removes it (on failure)
/// or transfers purchased products to the `paidProducts` collection (on success).
class FinishCheckoutPage extends StatefulWidget {
  /// Unique Firestore Order ID.
  final String orderId;

  /// Transaction ID provided by the payment gateway.
  final String txId;

  /// Indicates whether the transaction was successful.
  final bool success;

  /// Firestore user ID of the customer.
  final String userId;

  const FinishCheckoutPage({
    super.key,
    required this.orderId,
    required this.txId,
    required this.success,
    required this.userId,
  });

  @override
  State<FinishCheckoutPage> createState() => _FinishCheckoutPageState();
}

class _FinishCheckoutPageState extends State<FinishCheckoutPage> {
  /// Holds Firestore order data once loaded.
  Map<String, dynamic>? orderData;

  /// Controls the loading spinner while Firestore data is being fetched.
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder(); // Begin fetching order info upon widget initialization.
  }

  /// 🔹 Loads the corresponding order document from Firestore.
  ///
  /// If the order is not found, logs a warning.
  /// If the transaction failed, the order document is deleted immediately.
  Future<void> _loadOrder() async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      final doc = await docRef.get();

      if (!doc.exists) {
        debugPrint("⚠️ Order not found: ${widget.orderId}");
        setState(() => isLoading = false);
        return;
      }

      orderData = doc.data();

      if (!widget.success) {
        // ❌ Failed payment: remove the incomplete order from Firestore.
        await docRef.delete();
        debugPrint("🗑️ Deleted failed order: ${widget.orderId}");
      }
    } catch (e) {
      debugPrint("❌ Error loading order: $e");
    } finally {
      // Stop showing the loading spinner regardless of outcome.
      setState(() => isLoading = false);
    }
  }

  /// 🔹 Saves all purchased products to the `paidProducts` Firestore collection.
  ///
  /// Called only when the user returns home after a successful payment.
  /// Each product in the order is stored as a separate record, associated with:
  /// - user ID
  /// - transaction ID
  /// - order ID
  /// - customer details
  /// - payment method
  /// - timestamp
  Future<void> _savePaidProducts() async {
    if (orderData == null) return;

    final products =
        List<Map<String, dynamic>>.from(orderData?['productList'] ?? []);
    if (products.isEmpty) return;

    final paidProductsRef =
        FirebaseFirestore.instance.collection('paidProducts');

    for (var product in products) {
      await paidProductsRef.add({
        "userId": widget.userId,
        "orderId": widget.orderId,
        "txId": widget.txId,
        "product": product,
        "custName": orderData?['custName'] ?? '-',
        "custEmail": orderData?['custEmail'] ?? '-',
        "custContact": orderData?['custContact'] ?? '-',
        "address": orderData?['address'] ?? '-',
        "paymentMethod": getReadablePaymentMethod(orderData?['txChannel']),
        "deliveryStatus": orderData?['deliveryStatus'] ?? "not_started",
        "paidAt": DateTime.now(),
      });

    }

    // ✅ After recording payment, remove purchased items from the user's cart.
    await _clearPurchasedItemsFromCart(products);
  }

  /// 🔹 Removes purchased items from the user's Firestore cart collection.
  ///
  /// This ensures that items that have been successfully purchased no longer
  /// appear in the cart. It matches products by their document ID.
  Future<void> _clearPurchasedItemsFromCart(
      List<Map<String, dynamic>> purchasedProducts) async {
    final userCartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cart');

    for (var product in purchasedProducts) {
      final productId = product['id'];
      if (productId == null) continue;

      try {
        final docRef = userCartRef.doc(productId);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          await docRef.delete();
          debugPrint("🧹 Removed purchased cart item: $productId");
        } else {
          debugPrint("⚠️ Cart item not found for product: $productId");
        }
      } catch (e) {
        debugPrint("❌ Error removing $productId from cart: $e");
      }
    }
  }

  /// 🔹 Handles navigation when user taps "Return to Home".
  ///
  /// If payment succeeded, paid products are saved first.
  /// Then all navigation routes are popped until the root page.
  void _handleHome() async {
    if (widget.success) {
      await _savePaidProducts(); // Save paid items before returning home.
    }
    // ignore: use_build_context_synchronously
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// 🔹 Converts raw payment channel codes into human-readable labels.
  ///
  /// Example:
  /// - "EW" → "E-Wallet"
  /// - "CC" → "Credit Card"
  /// - "DD" → "Online Banking"
  String getReadablePaymentMethod(String? code) {
    switch (code) {
      case "EW":
        return "E-Wallet";
      case "CC":
        return "Credit Card";
      case "DD":
        return "Online Banking";
      default:
        return code ?? "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define visual indicators depending on transaction result.
    final icon = widget.success ? Icons.check_circle : Icons.error;
    final iconColor = widget.success ? Colors.green : Colors.red;
    final titleText = widget.success ? "Payment Successful!" : "Payment Failed";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Receipt"),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.success && orderData == null
              ? const Center(child: Text("Order not found"))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Transaction status header
                        Icon(icon, color: iconColor, size: 80),
                        const SizedBox(height: 8),
                        Text(
                          titleText,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 🔹 Transaction metadata
                        Text("Transaction ID: ${widget.txId}"),
                        Text("Order ID: ${widget.orderId}"),
                        Text(
                          "Payment Method: ${getReadablePaymentMethod(orderData?['txChannel'])}",
                        ),

                        if (widget.success) ...[
                          // ✅ Customer information section
                          const Divider(height: 32),
                          const Text(
                            "User Details",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text("Name: ${orderData?['custName'] ?? '-'}"),
                          Text("Email: ${orderData?['custEmail'] ?? '-'}"),
                          Text("Phone: ${orderData?['custContact'] ?? '-'}"),
                          Text("Address: ${orderData?['address'] ?? '-'}"),

                          // ✅ Order summary section
                          const Divider(height: 32),
                          const Text(
                            "Order Details",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          ...List.generate(
                            (orderData?['productList'] as List).length,
                            (i) {
                              final item = orderData!['productList'][i];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  "${item['name']} | Qty: ${item['qty']} | RM ${item['amount']}",
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // 🔹 Order pricing breakdown
                          Text(
                            "Subtotal: RM ${orderData?['txAmount'] != null ? (double.tryParse(orderData!['txAmount'])! - 5).toStringAsFixed(2) : '-'}",
                          ),
                          const Text("Delivery Fee: RM 0.00"),
                          Text(
                            "Total Paid: RM ${orderData?['txAmount'] ?? '-'}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // 🔹 Navigation button to return home
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.home),
                            label: const Text("Return to Home"),
                            onPressed: _handleHome,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
