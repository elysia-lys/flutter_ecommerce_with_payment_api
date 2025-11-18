/// ==============================
/// ORDER_CHECKOUT.DART
/// Checkout Form & Payment Processing
/// ==============================
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'call_api.dart';
import 'payment_webview.dart';
import '../main.dart'; // For SafeImage widget

/// ==============================
/// ORDER CHECKOUT WIDGET
/// ==============================

/// Stateful widget for handling order checkout.
/// 
/// Responsibilities:
/// - Display form for user info (name, address, email, phone)
/// - Display cart summary with items, subtotal, and total
/// - Allow selection of payment method
/// - Validate form inputs
/// - Save order to Firestore
/// - Initiate payment via API
/// - Redirect to payment webview
class OrderCheckout extends StatefulWidget {
  /// Firestore order ID
  final String orderId;

  /// List of items in the cart
  final List<Map<String, dynamic>> cartItems;

  /// Subtotal of all cart items
  final double subtotal;

  /// Firestore user ID
  final String userId;

  const OrderCheckout({
    super.key,
    required this.orderId,
    required this.cartItems,
    required this.subtotal,
    required this.userId,
  });

  @override
  State<OrderCheckout> createState() => _OrderCheckoutState();
}

/// ==============================
/// ORDER CHECKOUT STATE
/// ==============================

/// Handles:
/// - Form validation
/// - Payment initiation
/// - Cart & order processing
/// - UI rendering
class _OrderCheckoutState extends State<OrderCheckout> {
  // -----------------------------
  // FORM CONTROLLERS
  // -----------------------------
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();
  final numberController = TextEditingController();

  /// Selected payment method from dropdown
  String? selectedPayment;

  /// Supported payment methods
  final paymentMethods = ["Online Banking", "Credit Card", "E-Wallet"];

  // -----------------------------
  // COMPUTED VALUES
  // -----------------------------
  /// Total payable amount (subtotal + delivery fee)
  double get totalPay => widget.subtotal + 0.0; // delivery currently 0

  // -----------------------------
  // PAYMENT UTILITY
  // -----------------------------
  /// Converts payment method name to internal code
  String getChannelCode(String method) {
    switch (method) {
      case "Online Banking":
        return "DD";
      case "Credit Card":
        return "CC";
      case "E-Wallet":
        return "EW";
      default:
        return "CC";
    }
  }

  // -----------------------------
  // PAYMENT HANDLER
  // -----------------------------
  /// Validates inputs, saves order, and initiates payment
  Future<void> _handlePay() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedPayment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a payment method.")),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Processing your order...")),
      );

      final txChannel = getChannelCode(selectedPayment!);

      // -----------------------------
      // PREPARE ORDER DATA FOR FIRESTORE
      // -----------------------------
      final orderData = {
        "merchantId": "91012387",
        "txType": "SALE",
        "txChannel": txChannel,
        "orderId": widget.orderId,
        "orderRef": widget.orderId,
        "userId": widget.userId,
        "txCurrency": "MYR",
        "txAmount": totalPay.toStringAsFixed(2),
        "custName": nameController.text,
        "custEmail": emailController.text,
        "custContact": numberController.text,
        "address": addressController.text,
        "productList": widget.cartItems
            .map((i) => {
                  "id": i["id"],
                  "name": i["name"],
                  "qty": i["quantity"],
                  "amount": i["price"].toStringAsFixed(2),
                  "image": i["image"] ?? "assets/others/image_not_found.png",
                })
            .toList(),
        "status": "pending_payment",
        "createdAt": DateTime.now(),
      };

      // Save order in Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .set(orderData);

      // -----------------------------
      // INITIATE PAYMENT VIA API
      // -----------------------------
      final response = await CallApi.processPayment(
        totalAmount: totalPay,
        paymentMethod: selectedPayment!,
        items: widget.cartItems,
        userInfo: {
          "name": nameController.text,
          "email": emailController.text,
          "number": numberController.text,
          "address": addressController.text,
        },
        orderId: widget.orderId,
        userId: widget.userId,
      );

      if (response != null && response.containsKey("checkoutUrl")) {
        final checkoutUrl = response["checkoutUrl"];
        final txId = response["txId"] ?? "TX_UNKNOWN";

        // Navigate to PaymentWebView
        // ignore: use_build_context_synchronously
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebView(
              checkoutUrl: checkoutUrl,
              orderId: widget.orderId,
              txId: txId,
              userId: widget.userId,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to initiate payment: ${response?["message"] ?? "Unknown error"}",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Payment error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Payment failed due to an unexpected error.")),
      );
    }
  }

  // -----------------------------
  // FORM VALIDATION
  // -----------------------------
  /// Validates each form field based on label
  String? _validateField(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter your $label";
    }

    switch (label) {
      case "Full Name":
        if (!RegExp(r"^[A-Za-z]+(?: [A-Za-z]+)+$").hasMatch(value.trim())) {
          return "Please enter your full name (first and last name).";
        }
        if (value.trim().length < 5) {
          return "Name must be at least 5 characters long.";
        }
        break;

      case "Email":
        if (!RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(value.trim())) {
          return "Please enter a valid email address.";
        }
        break;

      case "Phone Number":
        if (!RegExp(r"^[0-9]{8,11}$").hasMatch(value.trim())) {
          return "Phone number must contain only digits (8–11 digits).";
        }
        break;

      case "Address":
        if (value.trim().length < 10) {
          return "Address must be at least 10 characters long.";
        }
        if (!RegExp(r"^(?=.*[A-Za-z])(?=.*[0-9])[A-Za-z0-9\s,.'-]+$")
            .hasMatch(value.trim())) {
          return "Address should include both letters and numbers.";
        }
        if (!value.contains(' ') && !value.contains(',')) {
          return "Please enter a more complete address (e.g., street and number).";
        }
        break;
    }

    return null;
  }

  // -----------------------------
  // WIDGET BUILDERS
  // -----------------------------
  /// Builds a labeled text field with validation
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.redAccent),
          ),
        ),
        validator: (v) => _validateField(label, v),
      ),
    );
  }

  /// Builds a cart summary list with items, subtotal, and total
  Widget _buildCartSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Items to Checkout",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        ...widget.cartItems.map(
          (item) => Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: SafeImage(
                item["image"] ?? "assets/others/image_not_found.png",
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
              title: Text(
                item["name"],
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                "Qty: ${item["quantity"]} | RM ${item["price"].toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text("Subtotal: RM ${widget.subtotal.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white)),
        const Text("Delivery: RM 0.00",
            style: TextStyle(color: Colors.white)),
        Text(
          "Total Pay: RM ${totalPay.toStringAsFixed(2)}",
          style: const TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ==============================
  // WIDGET BUILD
  // ==============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: Colors.redAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔹 Order metadata
              Text(
                "Order ID: ${widget.orderId}",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),

              /// 🔹 User info fields
              _buildTextField("Full Name", nameController),
              _buildTextField("Address", addressController),
              _buildTextField("Email", emailController),
              _buildTextField("Phone Number", numberController),
              const SizedBox(height: 16),

              /// 🔹 Payment method dropdown
              DropdownButtonFormField<String>(
                value: selectedPayment,
                decoration: const InputDecoration(
                  labelText: "Payment Method",
                  labelStyle: TextStyle(color: Colors.white),
                ),
                dropdownColor: Colors.black,
                items: paymentMethods
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedPayment = v),
              ),
              const SizedBox(height: 20),

              /// 🔹 Cart summary
              _buildCartSummary(),
              const SizedBox(height: 30),

              /// 🔹 Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _handlePay,
                    child: const Text(
                      "Pay Now",
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
