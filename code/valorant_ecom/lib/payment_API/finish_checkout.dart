/// ==============================
/// FINISH_CHECKOUT_PAGE.DART
/// Post-Payment Confirmation Screen
/// ==============================
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ==============================
/// FINISH CHECKOUT PAGE WIDGET
/// ==============================

/// Stateful widget for displaying post-payment confirmation.
/// 
/// Handles:
/// - Showing transaction success or failure
/// - Loading order data from Firestore
/// - Removing failed orders
/// - Recording successful orders in `paidProducts`
/// - Cleaning up user's cart after successful payment
/// - Navigating back to the home page
class FinishCheckoutPage extends StatefulWidget {
  /// Unique Firestore Order ID
  final String orderId;

  /// Payment gateway transaction ID
  final String txId;

  /// Whether the payment was successful
  final bool success;

  /// Firestore User ID
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

/// ==============================
/// FINISH CHECKOUT PAGE STATE
/// ==============================

/// Maintains state for [FinishCheckoutPage]
/// Responsible for:
/// - Loading order from Firestore
/// - Handling success/failure logic
/// - Saving paid products
/// - Cleaning user's cart
/// - Displaying transaction details
class _FinishCheckoutPageState extends State<FinishCheckoutPage> {
  // -----------------------------
  // STATE VARIABLES
  // -----------------------------

  /// Stores order data loaded from Firestore
  Map<String, dynamic>? orderData;

  /// Indicates if Firestore data is still being loaded
  bool isLoading = true;

  // -----------------------------
  // INITIALIZATION
  // -----------------------------

  @override
  void initState() {
    super.initState();
    _loadOrder(); // Load order details on widget initialization
  }

  // ==============================
  // FIRESTORE ORDER HANDLING
  // ==============================

  /// Loads the Firestore order document for the current order.
  ///
  /// If the order does not exist:
  /// - Logs a warning
  /// If the payment failed:
  /// - Deletes the order from Firestore
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
        // ❌ Remove failed order
        await docRef.delete();
        debugPrint("🗑️ Deleted failed order: ${widget.orderId}");
      }
    } catch (e) {
      debugPrint("❌ Error loading order: $e");
    } finally {
      setState(() => isLoading = false); // Stop loading spinner
    }
  }

  /// Saves each purchased product to the `paidProducts` Firestore collection.
  ///
  /// Each product document contains:
  /// - User ID
  /// - Order ID
  /// - Transaction ID
  /// - Customer info (name, email, contact, address)
  /// - Payment method
  /// - Delivery status
  /// - Timestamp of payment
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

    // ✅ Remove purchased items from user's cart
    await _clearPurchasedItemsFromCart(products);
  }

  /// Removes all purchased items from the user's Firestore cart.
  ///
  /// Ensures that successfully purchased products no longer appear in the cart.
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

  // ==============================
  // NAVIGATION
  // ==============================

  /// Handles "Return to Home" button tap.
  ///
  /// If payment was successful:
  /// - Saves paid products before returning home.
  /// Navigates back to the root page.
  void _handleHome() async {
    if (widget.success) {
      await _savePaidProducts();
    }
    // ignore: use_build_context_synchronously
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ==============================
  // PAYMENT METHOD UTILITY
  // ==============================

  /// Converts payment channel codes to human-readable labels.
  ///
  /// Examples:
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

  // ==============================
  // WIDGET BUILD
  // ==============================

  @override
  Widget build(BuildContext context) {
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
                        /// ✅ Transaction status header
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

                        /// 🔹 Transaction metadata
                        Text("Transaction ID: ${widget.txId}"),
                        Text("Order ID: ${widget.orderId}"),
                        Text(
                          "Payment Method: ${getReadablePaymentMethod(orderData?['txChannel'])}",
                        ),

                        if (widget.success) ...[
                          /// ✅ Customer information section
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

                          /// ✅ Order summary section
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

                          /// 🔹 Order pricing breakdown
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

                        /// 🔹 Navigation button to return home
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
