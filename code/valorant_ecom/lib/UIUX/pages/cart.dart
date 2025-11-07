import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/payment_API/order_checkout.dart';
import '../../main.dart'; // SafeImage widget for displaying images safely
import '../layout/layout.dart'; // Shared layout wrapper
import '../login_credential/login.dart'; // Redirect user to login page if no user is logged in

/// {@template cart_page}
/// A page that displays the user's shopping cart.
///
/// This widget retrieves the current logged-in user's cart items
/// from Firestore, allows them to manage product quantities,
/// select or deselect items for checkout, remove unwanted items,
/// and proceed to checkout.
/// {@endtemplate}
class CartPage extends StatefulWidget {
  /// Creates a [CartPage] widget.
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

/// State class for [CartPage].
///
/// Handles Firestore interactions, item updates, and checkout preparation.
class _CartPageState extends State<CartPage> {
  /// Currently logged-in user's Firestore document ID.
  String? userId;

  /// Indicates whether all items in the cart are selected.
  bool selectAll = true;

  /// Indicates whether the page is still loading user or Firestore data.
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// Checks Firestore for the currently logged-in user.
  ///
  /// If no user is logged in, redirects the user to the [LoginPage].
  Future<void> _checkLoginStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() {
          userId = loggedInUser.id;
          isLoading = false;
        });
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking login status: $e');
      setState(() => isLoading = false);
    }
  }

  /// Toggles the selection state for a single cart item.
  ///
  /// Updates the Firestore `selected` field for the specified [productId].
  Future<void> toggleItemSelection(String productId, bool value) async {
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(productId)
        .update({'selected': value});
  }

  /// Toggles the selection state for all items in the user's cart.
  ///
  /// Applies the same [value] (true or false) to all documents in Firestore.
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

  /// Deletes an item from the user's cart based on its [productId].
  Future<void> deleteItem(String productId) async {
    if (userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(productId)
        .delete();
  }

  /// Updates the quantity for a specific item.
  ///
  /// If [newQty] becomes zero or less, the item will be deleted.
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

  /// Computes the total amount of all selected items in the cart.
  ///
  /// Returns a [double] representing the calculated total.
  double computeTotal(List<Map<String, dynamic>> items) {
    return items
        .where((item) => item['selected'] == true)
        // ignore: avoid_types_as_parameter_names
        .fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  /// Generates a unique order ID and saves the order details in Firestore.
  ///
  /// Returns the generated [orderId] as a [String].
  Future<String> _generateOrderId(
      String userId, List<Map<String, dynamic>> selectedItems, double totalPrice) async {
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
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    if (userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text("Redirecting to login...",
                style: TextStyle(color: Colors.white))),
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
              /// Main list displaying all cart items.
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Card(
                      color: Colors.grey[900],
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: item['selected'] ?? true,
                              onChanged: (v) =>
                                  toggleItemSelection(item['id'], v ?? false),
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
                                      style: const TextStyle(color: Colors.white)),
                                  const SizedBox(height: 5),
                                  Text(
                                      "\$${item['price']} x ${item['quantity']}",
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove,
                                            color: Colors.redAccent),
                                        onPressed: () => updateQuantity(
                                            item['id'], item['quantity'] - 1),
                                      ),
                                      Text("${item['quantity']}",
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 16)),
                                      IconButton(
                                        icon: const Icon(Icons.add,
                                            color: Colors.greenAccent),
                                        onPressed: () => updateQuantity(
                                            item['id'], item['quantity'] + 1),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () => deleteItem(item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              /// Bottom summary section with total and checkout button.
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
                        // ignore: deprecated_member_use
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
                      Text("Total: \$${totalPrice.toStringAsFixed(2)}",
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
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
                                if (userId == null) return;
                                final orderId = await _generateOrderId(
                                    userId!, selectedItems, totalPrice);
                                Navigator.push(
                                  // ignore: use_build_context_synchronously
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
