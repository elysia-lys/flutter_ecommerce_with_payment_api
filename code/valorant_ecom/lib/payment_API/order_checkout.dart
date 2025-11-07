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

  /// Whether the "Pay Now" button should be displayed.
  bool showPayButton = false;

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

  /// Handles form validation and saving order details to Firestore.
  ///
  /// - Validates all text fields and checks that a payment method is selected.
  /// - Saves order data to the `orders` collection in Firestore.
  /// - Updates [showPayButton] to true to enable proceeding to payment.
  Future<void> _handleProceed() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedPayment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a payment method.")),
      );
      return;
    }

    final txChannel = getChannelCode(selectedPayment!);

    // Construct order document for Firestore
    final orderData = {
      "merchantId": "91012387",
      "txType": "SALE",
      "txChannel": txChannel,
      "orderId": widget.orderId,
      "orderRef": widget.orderId,
      "userId": widget.userId, // Link order to Firestore user
      "txCurrency": "MYR",
      "txAmount": totalPay.toStringAsFixed(2),
      "custName": nameController.text,
      "custEmail": emailController.text,
      "custContact": numberController.text,
      "address": addressController.text,
      "productList": widget.cartItems
          .map((i) => {
                "id": i["id"], // Optional product ID for tracking
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

    // Save order in Firestore
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .set(orderData);

    setState(() => showPayButton = true);

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Order saved. Ready for payment via $selectedPayment")),
    );
  }

  /// Initiates the payment process via the external API.
  ///
  /// - Calls [CallApi.processPayment] passing all relevant order and user information.
  /// - Redirects to [PaymentWebView] with the checkout URL and transaction ID.
  /// - Shows an error message if the payment initiation fails.
  Future<void> _handlePay() async {
    if (selectedPayment == null) return;

    try {
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
        userId: widget.userId, // Pass Firestore user ID for tracking
      );

      if (response != null && response.containsKey("checkoutUrl")) {
        final checkoutUrl = response["checkoutUrl"];
        final txId = response["txId"] ?? "TX_UNKNOWN";

        Navigator.pushReplacement(
          // ignore: use_build_context_synchronously
          context,
          MaterialPageRoute(
            builder: (_) => PaymentWebView(
              checkoutUrl: checkoutUrl,
              orderId: widget.orderId,
              txId: txId,
              userId: widget.userId, // Keep Firestore user ID
            ),
          ),
        );
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Failed to initiate payment: ${response?["message"] ?? "Unknown error"}")),
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
  ///
  /// [label] is displayed above the input.
  /// [controller] manages the field's value.
  Widget _buildTextField(String label, TextEditingController controller) =>
      Padding(
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
              title: Text(item["name"], style: const TextStyle(color: Colors.white)),
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
      appBar:
          AppBar(title: const Text("Checkout"), backgroundColor: Colors.redAccent),
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
                initialValue: selectedPayment,
                decoration: const InputDecoration(
                    labelText: "Payment Method",
                    labelStyle: TextStyle(color: Colors.white)),
                dropdownColor: Colors.black,
                items: paymentMethods
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (v) => setState(() => selectedPayment = v),
              ),
              const SizedBox(height: 20),
              _buildCartSummary(),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Cancel button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade900,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel", style: TextStyle(fontSize: 16)),
                        ),
                        // Proceed button (saves order)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          onPressed: _handleProceed,
                          child: const Text("Proceed", style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                    // Pay Now button shown after order is saved
                    if (showPayButton)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 14),
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
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
