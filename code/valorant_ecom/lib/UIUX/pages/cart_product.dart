// ==============================
// CART PRODUCT PAGE
// Displays a product from the cart but allows adding as new with same merge logic
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/cart.dart';
import 'package:valo/main.dart'; // SafeImage widget and cartCountNotifier
import 'package:valo/payment_API/order_checkout.dart';

/// `CartProductPage`
///
/// This page displays a single cart item in detail, allows selecting product options
/// (color, size, measurement), adjusting quantity, adding to cart (with merge logic
/// if the same options already exist), or proceeding to checkout directly.
class CartProductPage extends StatefulWidget {
  final Map<String, dynamic> product; // The cart item that was tapped
  final String userId; // Current user's Firestore document ID

  const CartProductPage({super.key, required this.product, required this.userId});

  @override
  State<CartProductPage> createState() => _CartProductPageState();
}

class _CartProductPageState extends State<CartProductPage> {
  int quantity = 1; // Quantity selected by the user
  String? selectedColor; // Selected color option
  String? selectedSize; // Selected size option
  String? selectedMeasurement; // Selected measurement option

  List<String> colors = []; // Available color options
  List<String> sizes = []; // Available size options
  List<String> measurements = []; // Available measurement options

  bool isLoading = true; // Tracks whether product options are being loaded
  bool isAddingToCart = false; // Tracks if "Add to Cart" is in progress

  @override
  void initState() {
    super.initState();
    _loadProductOptions(); // Load product options from Firestore when page opens
  }

  /// Load product options from Firestore
  /// For a product with the same name, fetch its color, size, and measurement options
  /// and store them in corresponding lists.
  Future<void> _loadProductOptions() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: widget.product['name'])
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      final data = query.docs.first.data();

      setState(() {
        colors = _parseOptions(data['color']); // Convert comma-separated string to list
        sizes = _parseOptions(data['size']);
        measurements = _parseOptions(data['measurement']);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading product options: $e');
      setState(() => isLoading = false);
    }
  }

  /// Convert a raw comma-separated string of options into a trimmed List<String>
  List<String> _parseOptions(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return [];
    return raw.toString().split(',').map((e) => e.trim()).toList();
  }

  /// Generate a unique cart document ID based on product name + selected options
  /// This ensures that adding the same product with same options merges quantity
  String _generateCartDocId() {
    final name = widget.product['name'] ?? '';
    final color = selectedColor ?? '';
    final size = selectedSize ?? '';
    final measurement = selectedMeasurement ?? '';
    return '${name}_${color}${size}${measurement}';
  }

  /// Show a dialog if quantity exceeds the maximum allowed (100)
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

  /// Add product to cart with merge logic
  ///
  /// - Validates required options (color, size, measurement)
  /// - Checks if a cart document with same options exists
  /// - If exists, increments the quantity
  /// - Otherwise, creates a new cart document
  /// - Updates the global cart badge via `cartCountNotifier`
  Future<void> addToCart() async {
    if (isAddingToCart) return;

    if (quantity > 100) {
      await _showMaxQtyDialog();
      return;
    }

    // Ensure all required options are selected
    if ((colors.isNotEmpty && selectedColor == null) ||
        (sizes.isNotEmpty && selectedSize == null) ||
        (measurements.isNotEmpty && selectedMeasurement == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required options!')),
      );
      return;
    }

    setState(() => isAddingToCart = true);

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cart');

    final docId = _generateCartDocId();
    final doc = await cartRef.doc(docId).get();

    double price = 0;
    try {
      price = double.parse(
        (widget.product['price'] ?? '0')
            .toString()
            .replaceAll(RegExp(r'[^0-9.]'), ''),
      );
    } catch (_) {}

    if (doc.exists) {
      // Merge quantity if same options already exist
      await cartRef.doc(docId).update({
        'quantity': (doc.data()?['quantity'] ?? 0) + quantity,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      // Add new cart document
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

    // Update cart badge count
    final snapshot = await cartRef.get();
    cartCountNotifier.value = snapshot.docs.length;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart!')),
      );
      setState(() => isAddingToCart = false);
    }
  }

  /// Checkout immediately with current selection
  ///
  /// Validates options and quantity, creates a temporary cart item,
  /// then navigates to `OrderCheckout` page with this single item.
  void _checkoutNow() async {
    if (quantity > 100) {
      await _showMaxQtyDialog();
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

    double price = 0;
    try {
      price = double.parse(
        (widget.product['price'] ?? '0')
            .toString()
            .replaceAll(RegExp(r'[^0-9.]'), ''),
      );
    } catch (_) {}

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
            userId: widget.userId,
          ),
        ),
      );
    }
  }

  /// Builds a dropdown menu for selecting product options
  /// Only displayed if the options list is non-empty
  Widget _buildDropdown(
      String label, List<String> options, String? value, Function(String?) onChanged) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        DropdownButton<String>(
          value: value,
          dropdownColor: Colors.black,
          hint: Text('Select $label', style: const TextStyle(color: Colors.white70)),
          items: options
              .map((opt) => DropdownMenuItem(
                    value: opt,
                    child: Text(opt, style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.redAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(product['name'] ?? 'Product'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image display
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
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  // Product price
                  Text(
                    "\$${double.tryParse(product['price'].toString())?.toStringAsFixed(2) ?? '0.00'}",
                    style: const TextStyle(fontSize: 18, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  // Option selectors
                  if (colors.isNotEmpty)
                    _buildDropdown("Color", colors, selectedColor, (v) => setState(() => selectedColor = v)),
                  if (sizes.isNotEmpty)
                    _buildDropdown("Size", sizes, selectedSize, (v) => setState(() => selectedSize = v)),
                  if (measurements.isNotEmpty)
                    _buildDropdown("Measurement", measurements, selectedMeasurement, (v) => setState(() => selectedMeasurement = v)),
                  // Quantity selector
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
                            if (parsed != null && parsed > 0) setState(() => quantity = parsed);
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                  // Action buttons: Add to Cart / Checkout Now
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent, padding: const EdgeInsets.all(16)),
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
                              backgroundColor: Colors.greenAccent, padding: const EdgeInsets.all(16)),
                          onPressed: _checkoutNow,
                          child: const Text('Checkout Now', style: TextStyle(fontSize: 16, color: Colors.black)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
