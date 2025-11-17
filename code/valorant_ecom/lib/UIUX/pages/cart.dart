import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/edit_cart_item.dart';
import 'package:valo/payment_API/order_checkout.dart';
import '../../main.dart'; // SafeImage widget
import '../layout/layout.dart'; // Shared layout
import '../login_credential/login.dart'; // Login redirect

/// Global cart count notifier to sync badge
final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

/// CartPage displays the user's shopping cart, allows managing items,
/// and provides checkout functionality.
class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String? userId;
  bool selectAll = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        userId = loggedInUser.id;
        await _updateCartCount();
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
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Updates the global cart badge
  Future<void> _updateCartCount() async {
    if (userId == null) return;
    final cartSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .get();
    cartCountNotifier.value = cartSnapshot.docs.length;
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> toggleItemSelection(String productId, bool value) async {
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(productId)
        .update({'selected': value});
  }

  Future<void> toggleSelectAll(bool value) async {
    if (userId == null) return;
    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart');
    final snapshot = await cartRef.get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'selected': value});
    }
    await batch.commit();
  }

  /// Delete an item and update badge immediately
  Future<void> deleteItem(String productId) async {
    if (userId == null) return;
    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart');

    await cartRef.doc(productId).delete();

    // Immediately update the badge, including when last item is deleted
    final snapshot = await cartRef.get();
    cartCountNotifier.value = snapshot.docs.length;
  }

  Future<void> updateQuantity(String productId, int newQty) async {
    if (userId == null) return;
    if (newQty > 0) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(productId)
          .update({'quantity': newQty});
    } else {
      await deleteItem(productId);
    }
  }

  double computeTotal(List<Map<String, dynamic>> items) {
    return items
        .where((item) => item['selected'] == true)
        .fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  Future<String> _generateOrderId(String userId,
      List<Map<String, dynamic>> selectedItems, double totalPrice) async {
    final orderId = "order${DateTime.now().millisecondsSinceEpoch}";

    await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
      "orderId": orderId,
      "userId": userId,
      "cartItems": selectedItems,
      "totalAmount": totalPrice,
      "paymentMethod": null,
      "status": "pending",
      "deliveryStatus": "Pending",
      "createdAt": DateTime.now(),
    });

    return orderId;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body:
            Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    if (userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("Redirecting to login...",
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .orderBy('timestamp', descending: true);

    return AppLayout(
      title: "My Cart",
      appBarActions: [],
      body: StreamBuilder<QuerySnapshot>(
        stream: cartRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cartItems = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();

          selectAll = cartItems.isNotEmpty &&
              cartItems.every((i) => i['selected'] == true);

          if (cartItems.isEmpty) {
            cartCountNotifier.value = 0; // clear badge when empty
            return const Center(
              child: Text("Your cart is empty.",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            );
          }

          final selectedItems =
              cartItems.where((i) => i['selected'] == true).toList();
          final totalPrice = computeTotal(cartItems);

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];

                    /// Build details string: color / size / measurement
                    final detailsList = [
                      if ((item['color'] ?? '').isNotEmpty) item['color'],
                      if ((item['size'] ?? '').isNotEmpty) item['size'],
                      if ((item['measurement'] ?? '').isNotEmpty)
                        item['measurement'],
                    ];
                    final details = detailsList.join(' / ');

                    return GestureDetector(
                      onTap: () async {
                        /// Open EditCartItemPage
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditCartItemPage(
                              userId: userId!,
                              cartDocId: item['id'],
                              item: item,
                            ),
                          ),
                        );

                        if (updated == true && mounted) {
                          setState(() {});
                          _updateCartCount();
                        }
                      },

                      child: Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: item['selected'] ?? true,
                                onChanged: (v) => toggleItemSelection(
                                    item['id'], v ?? false),
                                activeColor: Colors.redAccent,
                              ),
                              SafeImage(item['image'] ?? '',
                                  width: 50, height: 50, fit: BoxFit.cover),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    if (details.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          details,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14),
                                        ),
                                      ),
                                    const SizedBox(height: 5),
                                    Text("\$${item['price']} x ${item['quantity']}",
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove,
                                              color: Colors.redAccent),
                                          onPressed: () => updateQuantity(
                                              item['id'],
                                              item['quantity'] - 1),
                                        ),
                                        Text("${item['quantity']}",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16)),
                                        IconButton(
                                          icon: const Icon(Icons.add,
                                              color: Colors.greenAccent),
                                          onPressed: () => updateQuantity(
                                              item['id'],
                                              item['quantity'] + 1),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => deleteItem(item['id']),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Summary + Checkout button
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectAll,
                        onChanged: (v) => toggleSelectAll(v ?? false),
                        activeColor: Colors.redAccent,
                      ),
                      const Text("Select All",
                          style: TextStyle(color: Colors.white)),
                      const Spacer(),
                      Text(
                        "Total: \$${totalPrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedItems.isNotEmpty
                              ? Colors.redAccent
                              : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        onPressed: selectedItems.isNotEmpty
                            ? () async {
                                final orderId = await _generateOrderId(
                                    userId!, selectedItems, totalPrice);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OrderCheckout(
                                      cartItems: selectedItems,
                                      subtotal: totalPrice,
                                      orderId: orderId,
                                      userId: userId!,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        child: const Text("Checkout"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
