// ==============================
// PRODUCT PAGE
// Displays detailed view of a single product with selection options
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/login_credential/login.dart';
import 'package:valo/main.dart'; // SafeImage and cartCountNotifier
import 'package:valo/payment_API/order_checkout.dart';
import '../pages/cart.dart';

// ==============================
// PRODUCT PAGE WIDGET
// ==============================

/// ProductPage displays details for a single product.
///
/// Features:
/// - Shows product image, name, description, and price
/// - Allows selecting optional attributes: color, size, measurement
/// - Editable quantity input with max limit validation
/// - Add to Cart functionality
/// - Checkout Now functionality
/// - Checks login status and redirects if user is not logged in
class ProductPage extends StatefulWidget {
  /// Product data passed from previous page
  final Map<String, String> product;

  const ProductPage({super.key, required this.product});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

// ==============================
// PRODUCT PAGE STATE
// ==============================

class _ProductPageState extends State<ProductPage> {
  // ------------------------------
  // STATE VARIABLES
  // ------------------------------

  int quantity = 1; // Product quantity
  String? selectedColor; // Selected color option
  String? selectedSize; // Selected size option
  String? selectedMeasurement; // Selected measurement option
  String? userId; // Logged-in user's Firestore ID

  bool isAddingToCart = false; // Loading state for Add to Cart button

  // ------------------------------
  // GETTERS FOR PRODUCT OPTIONS
  // ------------------------------

  /// Returns a list of available colors for this product
  List<String> get colors => (widget.product['color'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Returns a list of available sizes for this product
  List<String> get sizes => (widget.product['size'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Returns a list of available measurements for this product
  List<String> get measurements => (widget.product['measurement'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  // ------------------------------
  // INITIALIZATION
  // ------------------------------

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Fetch logged-in user on page load
  }

  // ==============================
  // LOGIN CHECK
  // ==============================

  /// Checks if a user is logged in by querying Firestore
  /// - If logged in, sets the `userId`
  /// - If not, redirects to LoginPage
  Future<void> _checkLoginStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() => userId = loggedInUser.id);
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
    }
  }

  // ==============================
  // CART DOCUMENT ID GENERATION
  // ==============================

  /// Generates a unique document ID for the cart item
  /// based on name, color, size, and measurement
  String _generateCartDocId() {
    final name = widget.product['name'] ?? '';
    final color = selectedColor ?? '';
    final size = selectedSize ?? '';
    final measurement = selectedMeasurement ?? '';
    return '${name}_$color$size$measurement';
  }

  // ==============================
  // MAX QUANTITY DIALOG
  // ==============================

  /// Shows a dialog if user exceeds maximum quantity of 100
  Future<void> _showMaxQtyDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Maximum Quantity Exceeded'),
        content: const Text('The maximum quantity allowed is 100. Please reduce the quantity.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ==============================
  // ADD TO CART FUNCTIONALITY
  // ==============================

  /// Adds the product to the user's cart in Firestore
  /// - Handles validation for quantity and selected options
  /// - Updates cart badge count
  /// - Shows loading state and success SnackBar
  Future<void> addToCart() async {
    if (isAddingToCart) return;

    // Quantity validation
    if (quantity > 100) {
      await _showMaxQtyDialog();
      return;
    }

    setState(() => isAddingToCart = true);

    // Login check
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add to cart!')),
      );
      setState(() => isAddingToCart = false);
      return;
    }

    // Option selection validation
    if ((colors.isNotEmpty && selectedColor == null) ||
        (sizes.isNotEmpty && selectedSize == null) ||
        (measurements.isNotEmpty && selectedMeasurement == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required options!')),
      );
      setState(() => isAddingToCart = false);
      return;
    }

    // Parse product price safely
    double price = 0;
    try {
      price = double.parse((widget.product['price'] ?? '0').replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (_) {}

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart');

    final docId = _generateCartDocId();
    final doc = await cartRef.doc(docId).get();

    if (doc.exists) {
      // Update quantity if item exists
      await cartRef.doc(docId).update({
        'quantity': (doc.data()?['quantity'] ?? 1) + quantity,
      });
    } else {
      // Create new cart document
      await cartRef.doc(docId).set({
        'name': widget.product['name'] ?? '',
        'price': price,
        'quantity': quantity,
        'image': widget.product['image'] ?? '',
        'color': selectedColor ?? '',
        'size': selectedSize ?? '',
        'measurement': selectedMeasurement ?? '',
        'selected': true,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // Update cart badge
    await _updateCartBadge();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart!')),
      );
      await Future.delayed(const Duration(seconds: 1));
      setState(() => isAddingToCart = false);
    }
  }

  // ==============================
  // CART BADGE UPDATER
  // ==============================

  /// Updates the global cart count badge based on user's cart items
  Future<void> _updateCartBadge() async {
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .get();

    cartCountNotifier.value = snapshot.docs.length;
  }

  // ==============================
  // CHECKOUT FUNCTIONALITY
  // ==============================

  /// Directly proceeds to checkout with the selected product
  /// - Validates quantity and options
  /// - Generates a temporary order for checkout
  void _checkoutNow() async {
    if (quantity > 100) {
      await _showMaxQtyDialog();
      return;
    }

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to proceed!')),
      );
      return;
    }

    if ((colors.isNotEmpty && selectedColor == null) ||
        (sizes.isNotEmpty && selectedSize == null) ||
        (measurements.isNotEmpty && selectedMeasurement == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required options!')),
      );
      return;
    }

    // Parse price
    double price = 0;
    try {
      price = double.parse((widget.product['price'] ?? '0').replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (_) {}

    // Generate unique order ID
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();

    final cartItem = {
      "id": _generateCartDocId(),
      "name": widget.product['name'] ?? '',
      "quantity": quantity,
      "price": price,
      "image": widget.product['image'] ?? '',
      "color": selectedColor ?? '',
      "size": selectedSize ?? '',
      "measurement": selectedMeasurement ?? '',
    };

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderCheckout(
            orderId: orderId,
            cartItems: [cartItem],
            subtotal: price * quantity,
            userId: userId!,
          ),
        ),
      );
    }
  }

  // ==============================
  // BUILD WIDGET
  // ==============================

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return WillPopScope(
      onWillPop: () async {
        await _updateCartBadge(); // Update cart badge on back
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.redAccent),
            onPressed: () async {
              await _updateCartBadge();
              Navigator.pop(context);
            },
          ),
          title: Text(product['name'] ?? 'Product'),
        ),
        body: userId == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.redAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image
                    Center(
                      child: SafeImage(
                        product['image'] ?? 'assets/others/image_not_found.png',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Product name
                    Text(
                      product['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),

                    // Product price
                    Text(
                      product['price'] ?? '',
                      style: const TextStyle(
                          fontSize: 18, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 16),

                    // Product description
                    Text(
                      product['desc'] ?? '',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),

                    // Dropdowns for color, size, measurement
                    if (colors.isNotEmpty) ...[
                      const Text('Color:', style: TextStyle(color: Colors.white, fontSize: 16)),
                      DropdownButton<String>(
                        value: selectedColor,
                        dropdownColor: Colors.black,
                        hint: const Text('Select Color', style: TextStyle(color: Colors.white70)),
                        items: colors
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => selectedColor = v),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (sizes.isNotEmpty) ...[
                      const Text('Size:', style: TextStyle(color: Colors.white, fontSize: 16)),
                      DropdownButton<String>(
                        value: selectedSize,
                        dropdownColor: Colors.black,
                        hint: const Text('Select Size', style: TextStyle(color: Colors.white70)),
                        items: sizes
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s, style: const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => selectedSize = v),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (measurements.isNotEmpty) ...[
                      const Text('Measurement:', style: TextStyle(color: Colors.white, fontSize: 16)),
                      DropdownButton<String>(
                        value: selectedMeasurement,
                        dropdownColor: Colors.black,
                        hint: const Text('Select Measurement', style: TextStyle(color: Colors.white70)),
                        items: measurements
                            .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m, style: const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => selectedMeasurement = v),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Quantity input
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quantity:', style: TextStyle(color: Colors.white, fontSize: 16)),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            initialValue: quantity.toString(),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[900],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed > 0) {
                                setState(() => quantity = parsed);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

                    // Buttons: Add to Cart & Checkout
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.all(16),
                            ),
                            onPressed: isAddingToCart ? null : addToCart,
                            child: isAddingToCart
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Add to Cart', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              padding: const EdgeInsets.all(16),
                            ),
                            onPressed: _checkoutNow,
                            child: const Text('Checkout Now', style: TextStyle(fontSize: 16, color: Colors.black)),
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
