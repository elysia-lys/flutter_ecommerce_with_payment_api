// ==============================
// FAVORITE PAGE
// Displays the user's favorite products
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/product.dart'; // ProductPage for product details
import '../../main.dart'; // SafeImage widget
import '../layout/layout.dart'; // Shared AppLayout

// ==============================
// FAVORITE PAGE WIDGET
// ==============================

/// FavoritePage displays all products the logged-in user has liked.
///
/// Features:
/// - Fetches logged-in user ID from Firestore
/// - Streams real-time updates of user's `favorites` collection
/// - Displays products in a responsive grid
/// - Allows removing products from favorites
class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

// ==============================
// STATE CLASS
// ==============================

class _FavoritePageState extends State<FavoritePage> {
  /// Stores the logged-in Firestore user's document ID
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchLoggedInUserId(); // Fetch user on page load
  }

  // ==============================
  // FETCH LOGGED-IN USER
  // ==============================

  /// Fetches the Firestore document ID of the currently logged-in user.
  ///
  /// Searches `users` collection for a document with `loggedIn` == true.
  /// If found, sets `_userId`, otherwise prints debug warning.
  Future<void> _fetchLoggedInUserId() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() {
          _userId = loggedInUser.id;
        });
      } else {
        debugPrint("⚠️ No user is logged in.");
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching logged-in user: $e');
    }
  }

  // ==============================
  // FIRESTORE STREAM
  // ==============================

  /// Returns a real-time stream of the user's favorite products.
  ///
  /// Listens to `favorites` subcollection under the logged-in user's document.
  Stream<QuerySnapshot>? get favoriteStream {
    if (_userId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('favorites')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ==============================
  // REMOVE FAVORITE
  // ==============================

  /// Removes a product from favorites using its [productId].
  Future<void> removeFavorite(String productId) async {
    if (_userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('favorites')
          .doc(productId)
          .delete();
      debugPrint('🗑️ Removed favorite: $productId');
    } catch (e) {
      debugPrint('🔥 Error removing favorite: $e');
    }
  }

  // ==============================
  // PRODUCT CARD
  // ==============================

  /// Builds a single product card for the favorite item.
  ///
  /// Features:
  /// - Displays product image, name, description, price
  /// - Tappable to navigate to ProductPage
  /// - Heart icon to remove from favorites
  Widget buildProductCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GestureDetector(
      onTap: () {
        // Navigate to detailed ProductPage
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductPage(
              product: {
                "id": doc.id,
                "name": data['name'] ?? '',
                "desc": data['desc'] ?? '',
                "price": data['price'] ?? '',
                "category": data['category'] ?? '',
                "type": data['type'] ?? '',
                "size": data['size'] ?? '',
                "color": data['color'] ?? '',
                "measurement": data['measurement'] ?? '',
                "image": data['image'] ?? 'assets/idk.png',
              },
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // Product card container
          Container(
            width: 140,
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                SizedBox(
                  height: 100,
                  child: SafeImage(
                    data['image'] ?? 'assets/idk.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 6),

                // Product name
                Text(
                  data['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Short description
                Text(
                  data['desc'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Price
                Text(
                  data['price'] ?? '\$0',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Favorite (heart) icon
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => removeFavorite(doc.id),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.redAccent,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================
  // BUILD PAGE
  // ==============================

  @override
  Widget build(BuildContext context) {
    // Show loader until userId is fetched
    if (_userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    // Main layout using shared AppLayout
    return AppLayout(
      title: "My Favorites",
      appBarActions: const [],
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: favoriteStream,
          builder: (context, snapshot) {
            // Show loading indicator while fetching data
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              );
            }

            final favoriteDocs = snapshot.data?.docs ?? [];

            // Empty state
            if (favoriteDocs.isEmpty) {
              return const Center(
                child: Text(
                  "No favorites yet!",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              );
            }

            // Display favorite items in a responsive wrap
            return SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.start,
                children: favoriteDocs
                    .map((doc) => buildProductCard(context, doc))
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
