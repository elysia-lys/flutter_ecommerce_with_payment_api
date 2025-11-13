import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'call_api.dart';
import 'payment_webview.dart';
import '../main.dart'; // Import SafeImage for displaying product images

/// Checkout page for placing and paying an order.
///
/// This page handles:
/// - User input for delivery information
/// - Selection of payment method
/// - Saving order data to Firestore
/// - Redirecting to the payment gateway
///
/// Requires the user's Firestore [userId], the order ID, a list of cart items,
/// and the subtotal amount.
class OrderCheckout extends StatefulWidget {
  /// The unique identifier for this order.
  final String orderId;

  /// List of cart items, each represented as a Map containing product details.
  final List<Map<String, dynamic>> cartItems;

  /// The subtotal amount for all items in the cart.
  final double subtotal;

  /// Firestore user ID for associating the order with the logged-in user.
  final String userId;

  /// Creates an OrderCheckout page.
  ///
  /// All fields are required to ensure proper functionality.
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

class _OrderCheckoutState extends State<OrderCheckout> {
  /// Global key to validate the checkout form.
  final _formKey = GlobalKey<FormState>();

  /// Controller for the customer's full name input field.
  final nameController = TextEditingController();

  /// Controller for the customer's delivery address input field.
  final addressController = TextEditingController();

  /// Controller for the customer's email input field.
  final emailController = TextEditingController();

  /// Controller for the customer's phone number input field.
  final numberController = TextEditingController();

  /// Selected payment method from the dropdown.
  String? selectedPayment;

  /// List of supported payment methods.
  final paymentMethods = ["Online Banking", "Credit Card", "E-Wallet"];

  /// Computes the total amount payable including subtotal and additional charges.
  ///
  /// Currently, no additional charges are applied (delivery fee = 0.0).
  double get totalPay => widget.subtotal + 0.0;

  /// Returns the channel code required by the payment gateway for [method].
  ///
  /// - "DD" → Online Banking
  /// - "CC" → Credit Card
  /// - "EW" → E-Wallet
  /// Defaults to "CC" if method is unrecognized.
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

  /// Handles full checkout process: validate, save to Firestore, then initiate payment.
  Future<void> _handlePay() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedPayment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a payment method.")),
      );
      return;
    }

    try {
      // Show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Processing your order...")),
      );

      final txChannel = getChannelCode(selectedPayment!);

      // Construct order document for Firestore
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
        "deliveryStatus": "not_started",
        "createdAt": DateTime.now(),
      };

      // Step 1: Save order to Firestore
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .set(orderData);

      // Step 2: Call payment API
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

      // Step 3: Redirect to payment page
      if (response != null && response.containsKey("checkoutUrl")) {
        final checkoutUrl = response["checkoutUrl"];
        final txId = response["txId"] ?? "TX_UNKNOWN";

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
        // ignore: use_build_context_synchronously
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
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment failed due to an unexpected error.")),
      );
    }
  }

  /// Builds a reusable text form field with validation.
  Widget _buildTextField(String label, TextEditingController controller) => Padding(
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
          validator: (v) => v!.isEmpty ? "Please enter $label" : null,
        ),
      );

  /// Builds the cart summary widget showing all items, subtotal, and total payable.
  Widget _buildCartSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Items to Checkout",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
              title:
                  Text(item["name"], style: const TextStyle(color: Colors.white)),
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
        Text("Delivery: RM 0.00", style: const TextStyle(color: Colors.white)),
        Text("Total Pay: RM ${totalPay.toStringAsFixed(2)}",
            style: const TextStyle(
                color: Colors.greenAccent, fontWeight: FontWeight.bold)),
      ],
    );
  }

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
              Text("Order ID: ${widget.orderId}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 10),
              _buildTextField("Full Name", nameController),
              _buildTextField("Address", addressController),
              _buildTextField("Email", emailController),
              _buildTextField("Phone Number", numberController),
              const SizedBox(height: 16),

              // Dropdown for selecting payment method
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
                        child: Text(m, style: const TextStyle(color: Colors.white)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selectedPayment = v),
              ),
              const SizedBox(height: 20),

              _buildCartSummary(),
              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text("Cancel", style: TextStyle(fontSize: 16)),
                  ),

                  // Single Pay Now button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
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
