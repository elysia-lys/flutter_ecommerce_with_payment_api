// ignore_for_file: unused_local_variable, unused_import

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/login_credential/login.dart';
import 'package:valo/main.dart';

/// A page that displays detailed product information and allows
/// the user to select variations (color, size, measurement) and
/// add the product to their Firestore shopping cart.
///
/// This widget automatically checks for a logged-in user in Firestore.
/// If no user is logged in, the page redirects to [LoginPage].
///
/// Example usage:
/// ```dart
/// ProductPage(product: {
///   'name': 'T-Shirt',
///   'price': 'RM29.90',
///   'color': 'Red, Blue, Black',
///   'size': 'S, M, L',
///   'image': 'assets/images/tshirt.png',
/// });
/// ```
class ProductPage extends StatefulWidget {
  /// A map containing the product’s details (name, price, color, size, etc.).
  final Map<String, String> product;

  /// Creates a new [ProductPage] widget.
  const ProductPage({super.key, required this.product});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

/// Internal state class for [ProductPage].
///
/// Handles Firestore integration, user authentication check,
/// and add-to-cart functionality.
class _ProductPageState extends State<ProductPage> {
  int quantity = 1;
  String? selectedColor;
  String? selectedSize;
  String? selectedMeasurement;
  String? userId;

  /// Extracts available color options from the product map.
  List<String> get colors => (widget.product['color'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Extracts available size options from the product map.
  List<String> get sizes => (widget.product['size'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Extracts available measurement options from the product map.
  List<String> get measurements => (widget.product['measurement'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// Checks Firestore for the currently logged-in user.
  ///
  /// If a user document with `"loggedIn": true` is found,
  /// the user’s ID is stored for subsequent Firestore operations.
  ///
  /// If no user is logged in, the app navigates to [LoginPage].
  Future<void> _checkLoginStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() => userId = loggedInUser.id);
      } else {
        debugPrint("⚠️ No user logged in, redirecting to LoginPage...");
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking login status: $e');
    }
  }

  /// Generates a unique document ID for a product in the user's cart.
  ///
  /// Combines product name with selected variations to ensure uniqueness.
  /// Example: `T-Shirt_RedM`.
  String _generateCartDocId() {
    final name = widget.product['name'] ?? '';
    final color = selectedColor ?? '';
    final size = selectedSize ?? '';
    final measurement = selectedMeasurement ?? '';
    return '${name}_$color$size$measurement';
  }

  /// Adds the current product and its selected variations to Firestore cart.
  ///
  /// Validates login status and ensures all required options (color, size, etc.)
  /// are selected before saving. If the same variation already exists in the cart,
  /// the quantity is updated instead of creating a duplicate entry.
  Future<void> addToCart() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add to cart!')),
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

    double price = 0;
    try {
      price = double.parse(
          (widget.product['price'] ?? '0').replaceAll(RegExp(r'[^0-9.]'), ''));
    } catch (_) {}

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart');

    final docId = _generateCartDocId();
    final doc = await cartRef.doc(docId).get();

    if (doc.exists) {
      await cartRef.doc(docId).update({
        'quantity': (doc.data()?['quantity'] ?? 1) + quantity,
      });
    } else {
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

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(product['name'] ?? 'Product'),
        backgroundColor: Colors.black,
      ),
      body: userId == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Product image section
                  Center(
                    child: SafeImage(
                      product['image'] ?? 'assets/others/image_not_found.png',
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),

                  /// Product title
                  Text(
                    product['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  /// Product price
                  Text(
                    product['price'] ?? '',
                    style: const TextStyle(
                        fontSize: 18, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),

                  /// Product description
                  Text(
                    product['desc'] ?? '',
                    style:
                        const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),

                  /// Color selector
                  if (colors.isNotEmpty) ...[
                    const Text('Color:',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    DropdownButton<String>(
                      value: selectedColor,
                      dropdownColor: Colors.black,
                      hint: const Text('Select Color',
                          style: TextStyle(color: Colors.white70)),
                      items: colors
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c,
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => selectedColor = v),
                    ),
                    const SizedBox(height: 10),
                  ],

                  /// Size selector
                  if (sizes.isNotEmpty) ...[
                    const Text('Size:',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    DropdownButton<String>(
                      value: selectedSize,
                      dropdownColor: Colors.black,
                      hint: const Text('Select Size',
                          style: TextStyle(color: Colors.white70)),
                      items: sizes
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s,
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => selectedSize = v),
                    ),
                    const SizedBox(height: 10),
                  ],

                  /// Measurement selector
                  if (measurements.isNotEmpty) ...[
                    const Text('Measurement:',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    DropdownButton<String>(
                      value: selectedMeasurement,
                      dropdownColor: Colors.black,
                      hint: const Text('Select Measurement',
                          style: TextStyle(color: Colors.white70)),
                      items: measurements
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => selectedMeasurement = v),
                    ),
                    const SizedBox(height: 20),
                  ],

                  /// Quantity selector
                  Row(
                    children: [
                      const Text('Quantity:',
                          style:
                              TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white),
                        onPressed:
                            quantity > 1 ? () => setState(() => quantity--) : null,
                      ),
                      Text('$quantity',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => setState(() => quantity++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  /// Add to Cart button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: addToCart,
                      child: const Text('Add to Cart',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
