import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/product.dart';// ProductPage import
import '../../main.dart'; // SafeImage widget import
import '../layout/layout.dart';

/// A page that displays the list of favorite products saved by a logged-in user.
///
/// The [FavoritePage] fetches and listens to real-time updates from Firestore,
/// specifically the `favorites` subcollection under the logged-in user’s document.
/// Users can view, open, and remove their favorite items from this page.
class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

/// State class for [FavoritePage].
///
/// This class manages fetching the logged-in user ID, retrieving
/// favorite products, and handling user interactions such as removing favorites.
class _FavoritePageState extends State<FavoritePage> {
  /// Stores the currently logged-in Firestore user’s document ID.
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchLoggedInUserId();
  }

  /// Fetches the Firestore document ID of the currently logged-in user.
  ///
  /// Checks the `users` collection for any document where the `loggedIn` field
  /// is set to `true`. If a logged-in user is found, their document ID is stored
  /// in [_userId]. Otherwise, a debug warning is printed.
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
      debugPrint('⚠️ Error checking login status: $e');
    }
  }

  /// A real-time Firestore stream that provides updates to the user's favorite items.
  ///
  /// Returns a [Stream] of [QuerySnapshot] objects that listen to the `favorites`
  /// subcollection under the logged-in user's document.
  Stream<QuerySnapshot>? get favoriteStream {
    if (_userId == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('favorites')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Removes a specific product from the user's list of favorites.
  ///
  /// Takes the [productId] as input and deletes the corresponding document
  /// from the user's `favorites` subcollection in Firestore.
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
      debugPrint('🔥 Remove favorite error: $e');
    }
  }

  /// Builds a card widget to display individual favorite product details.
  ///
  /// Each card shows the product’s image, name, description, and price.
  /// When tapped, the card navigates to the [ProductPage] for more details.
  ///
  /// A heart icon in the top-right corner allows removing the product
  /// from the favorites list.
  Widget buildProductCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return GestureDetector(
      onTap: () {
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
          Container(
            width: 140,
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Displays the product image safely using the [SafeImage] widget.
                SizedBox(
                  height: 100,
                  child: SafeImage(
                    data['image'] ?? 'assets/idk.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 6),

                /// Product name text (bold white).
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

                /// Short product description.
                Text(
                  data['desc'] ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                /// Product price in red.
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

          /// Favorite (heart) icon positioned at the top-right corner.
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

  /// Builds the main UI for the FavoritePage.
  ///
  /// Displays a loading spinner while fetching data, an empty message if
  /// no favorites exist, or a responsive grid of favorite product cards otherwise.
  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    return AppLayout(
      title: "My Favorites",
      appBarActions: const [],
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: favoriteStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.redAccent),
              );
            }

            final favoriteDocs = snapshot.data?.docs ?? [];

            if (favoriteDocs.isEmpty) {
              return const Center(
                child: Text(
                  "No favorites yet!",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              );
            }

            /// Displays all favorite items in a responsive wrap layout.
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
