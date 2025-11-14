// ignore_for_file: unused_local_variable, unused_import

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/login_credential/login.dart';
import 'package:valo/main.dart';
import 'package:valo/payment_API/order_checkout.dart';
import '../pages/cart.dart';


class ProductPage extends StatefulWidget {
  final Map<String, String> product;

  const ProductPage({super.key, required this.product});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  int quantity = 1;
  String? selectedColor;
  String? selectedSize;
  String? selectedMeasurement;
  String? userId;

  bool isAddingToCart = false;

  List<String> get colors => (widget.product['color'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> get sizes => (widget.product['size'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

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

  String _generateCartDocId() {
    final name = widget.product['name'] ?? '';
    final color = selectedColor ?? '';
    final size = selectedSize ?? '';
    final measurement = selectedMeasurement ?? '';
    return '${name}_$color$size$measurement';
  }

  Future<void> addToCart() async {
    if (isAddingToCart) return;
    setState(() => isAddingToCart = true);

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add to cart!')),
      );
      setState(() => isAddingToCart = false);
      return;
    }

    if ((colors.isNotEmpty && selectedColor == null) ||
        (sizes.isNotEmpty && selectedSize == null) ||
        (measurements.isNotEmpty && selectedMeasurement == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select all required options!')),
      );
      setState(() => isAddingToCart = false);
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

    await _updateCartBadge();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart!')),
      );
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => isAddingToCart = false);
  }

  Future<void> _updateCartBadge() async {
    if (userId == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .get();
    cartCountNotifier.value = snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return WillPopScope(
      onWillPop: () async {
        await _updateCartBadge();
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
                    Center(
                      child: SafeImage(
                        product['image'] ?? 'assets/others/image_not_found.png',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(product['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(product['price'] ?? '',
                        style: const TextStyle(
                            fontSize: 18, color: Colors.redAccent)),
                    const SizedBox(height: 16),
                    Text(product['desc'] ?? '',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 20),

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
                                        const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => selectedColor = v),
                      ),
                      const SizedBox(height: 10),
                    ],

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
                                        const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => selectedSize = v),
                      ),
                      const SizedBox(height: 10),
                    ],

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
                                        const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => selectedMeasurement = v),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Row(
                      children: [
                        const Text('Quantity:',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
                        const SizedBox(width: 10),
                        IconButton(
                          icon:
                              const Icon(Icons.remove, color: Colors.white),
                          onPressed: quantity > 1
                              ? () => setState(() => quantity--)
                              : null,
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

                    // Buttons Column
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
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Add to Cart',
                                    style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ✅ Checkout Now Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              padding: const EdgeInsets.all(16),
                            ),
                            onPressed: () {
                              if (userId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Please log in to proceed!')),
                                );
                                return;
                              }

                              if ((colors.isNotEmpty && selectedColor == null) ||
                                  (sizes.isNotEmpty && selectedSize == null) ||
                                  (measurements.isNotEmpty &&
                                      selectedMeasurement == null)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please select all required options!')),
                                );
                                return;
                              }

                              double price = 0;
                              try {
                                price = double.parse((widget.product['price'] ??
                                        '0')
                                    .replaceAll(RegExp(r'[^0-9.]'), ''));
                              } catch (_) {}

                              final orderId =
                                  DateTime.now().millisecondsSinceEpoch.toString();

                              final cartItem = {
                                "id": _generateCartDocId(),
                                "name": widget.product['name'] ?? '',
                                "quantity": quantity,
                                "price": price,
                                "image":
                                    widget.product['image'] ?? '',
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
                            },
                            child: const Text('Checkout Now',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black)),
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
