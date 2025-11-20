// ==============================
// CART PRODUCT PAGE
// Displays a product from the cart but allows adding as new with same merge logic
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/cart.dart';
import 'package:valo/main.dart'; // SafeImage widget and cartCountNotifier
import 'package:valo/payment_API/order_checkout.dart';

class CartProductPage extends StatefulWidget {
  final Map<String, dynamic> product; // Cart item tapped
  final String userId;

  const CartProductPage({super.key, required this.product, required this.userId});

  @override
  State<CartProductPage> createState() => _CartProductPageState();
}

class _CartProductPageState extends State<CartProductPage> {
  int quantity = 1;
  String? selectedColor;
  String? selectedSize;
  String? selectedMeasurement;

  List<String> colors = [];
  List<String> sizes = [];
  List<String> measurements = [];

  bool isLoading = true;
  bool isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _loadProductOptions();
  }

  /// Load options from Firestore like EditCartItemPage
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
        colors = _parseOptions(data['color']);
        sizes = _parseOptions(data['size']);
        measurements = _parseOptions(data['measurement']);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading product options: $e');
      setState(() => isLoading = false);
    }
  }

  List<String> _parseOptions(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return [];
    return raw.toString().split(',').map((e) => e.trim()).toList();
  }

  /// Generate cart document ID
  String _generateCartDocId() {
    final name = widget.product['name'] ?? '';
    final color = selectedColor ?? '';
    final size = selectedSize ?? '';
    final measurement = selectedMeasurement ?? '';
    return '${name}_${color}${size}${measurement}';
  }

  /// Show max quantity dialog
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

  /// Add to cart button logic
  Future<void> addToCart() async {
    if (isAddingToCart) return;

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
      // Merge quantity
      await cartRef.doc(docId).update({
        'quantity': (doc.data()?['quantity'] ?? 0) + quantity,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      // Add new
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

    // Update global cart badge
    final snapshot = await cartRef.get();
    cartCountNotifier.value = snapshot.docs.length;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart!')),
      );
      setState(() => isAddingToCart = false);
    }
  }

  /// Checkout button logic
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

  Widget _buildDropdown(String label, List<String> options, String? value, Function(String?) onChanged) {
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
                  Center(
                    child: SafeImage(
                      product['image'] ?? 'assets/others/image_not_found.png',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    product['name'] ?? '',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "\$${double.tryParse(product['price'].toString())?.toStringAsFixed(2) ?? '0.00'}",
                    style: const TextStyle(fontSize: 18, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  if (colors.isNotEmpty) _buildDropdown("Color", colors, selectedColor, (v) => setState(() => selectedColor = v)),
                  if (sizes.isNotEmpty) _buildDropdown("Size", sizes, selectedSize, (v) => setState(() => selectedSize = v)),
                  if (measurements.isNotEmpty)
                    _buildDropdown("Measurement", measurements, selectedMeasurement, (v) => setState(() => selectedMeasurement = v)),
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
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.all(16)),
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, padding: const EdgeInsets.all(16)),
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
