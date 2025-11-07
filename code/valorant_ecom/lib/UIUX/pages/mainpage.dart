import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:valo/UIUX/layout/layout.dart';
import 'package:valo/UIUX/login_credential/login.dart';
import 'package:valo/main.dart';
import 'product.dart';

/// A global set containing IDs of products that the user has liked.
///
/// This set is updated whenever a product is favorited or unfavorited.
/// It is shared across sessions and used to reflect liked states on UI components.
Set<String> likedProducts = {};

/// The main landing page of the e-commerce application.
///
/// Displays promotional banners, top product picks, and handles
/// authentication checks before rendering product data.
///
/// This page is only accessible to logged-in users. If no active
/// session is detected, users are redirected to the [LoginPage].
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  /// The ID of the currently logged-in user (retrieved from Firestore).
  String? userId;

  /// List of products retrieved from Firestore.
  List<Map<String, String>> products = [];

  /// A shuffled subset of [products] displayed under “Top Picks”.
  List<Map<String, String>> topPicks = [];

  /// Whether the app is currently fetching product data.
  bool isLoadingProducts = true;

  /// Whether the app is still verifying the user's login status.
  bool isCheckingLogin = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// Verifies user login state using Firestore before loading products.
  ///
  /// If a logged-in user is found, this method:
  /// - Stores their [userId]
  /// - Loads available products via [_loadProducts]
  /// - Loads their favorite products via [_loadFavorites]
  ///
  /// If no logged-in user is detected, the app redirects to [LoginPage].
  Future<void> _checkLoginStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() {
          userId = loggedInUser.id;
          isCheckingLogin = false;
        });
        await _loadProducts();
        await _loadFavorites();
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
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    }
  }

  /// Loads product data from Firestore and prepares the [products] and [topPicks] lists.
  ///
  /// - Fetches up to 30 product documents from the `products` collection.
  /// - Converts each document into a standardized `Map<String, String>`.
  /// - Randomizes and truncates the list to generate `topPicks`.
  Future<void> _loadProducts() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('products').limit(30).get();

      final loaded = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name']?.toString() ?? '',
          'desc': data['desc']?.toString() ?? '',
          'price': data['price']?.toString() ?? '',
          'image': data['image']?.toString() ?? 'assets/others/image_not_found.png',
          'category': data['category']?.toString() ?? '',
          'type': data['type']?.toString() ?? '',
          'size': data['size']?.toString() ?? '',
          'color': data['color']?.toString() ?? '',
          'measurement': data['measurement']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        products = loaded;
        topPicks = List<Map<String, String>>.from(loaded)..shuffle();
        if (topPicks.length > 20) topPicks = topPicks.sublist(0, 20);
        isLoadingProducts = false;
      });
    } catch (e) {
      debugPrint('Firestore load error: $e');
      setState(() => isLoadingProducts = false);
    }
  }

  /// Loads the user's favorite products from Firestore.
  ///
  /// Queries the subcollection `favorites` under the user’s document.
  /// Updates the [likedProducts] set with all favorite product IDs.
  Future<void> _loadFavorites() async {
    if (userId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      setState(() {
        likedProducts = snapshot.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  /// Adds the given [product] to the user's favorites list in Firestore.
  ///
  /// Automatically records a timestamp for the addition.
  Future<void> _addFavorite(Map<String, String> product) async {
    if (userId == null) return;
    final productId = product['id'] ?? DateTime.now().toString();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(productId)
        .set({
      ...product,
      'timestamp': FieldValue.serverTimestamp(),
    });
    setState(() => likedProducts.add(productId));
  }

  /// Removes the given [product] from the user's favorites list in Firestore.
  Future<void> _removeFavorite(Map<String, String> product) async {
    if (userId == null) return;
    final productId = product['id'];
    if (productId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(productId)
        .delete();
    setState(() => likedProducts.remove(productId));
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Display loading spinner while verifying authentication.
    if (isCheckingLogin) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    // 🔹 Render main product page after authentication is verified.
    return AppLayout(
      title: '',
      appBarActions: [],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BannerSection(),
            if (isLoadingProducts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30.0),
                  child: CircularProgressIndicator(color: Colors.redAccent),
                ),
              )
            else if (topPicks.isNotEmpty)
              TopPicksSection(
                products: topPicks,
                addFavorite: _addFavorite,
                removeFavorite: _removeFavorite,
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30.0),
                  child: Text(
                    "No products found.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------
/// BANNER SECTION
/// ---------------------------

/// Displays a carousel of promotional banners linking to external URLs.
///
/// Each banner image acts as a clickable advertisement
/// that launches the corresponding link in the user’s browser.
class BannerSection extends StatelessWidget {
  const BannerSection({super.key});

  /// Launches a URL externally using the device’s browser.
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  /// Builds a single banner card with image and external link.
  Widget _bannerCard(String imagePath, String url) {
    return GestureDetector(
      onTap: () => _launchURL(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SafeImage(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 200,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CarouselSlider(
      items: [
        _bannerCard("assets/others/valorant_game.jpeg", "https://playvalorant.com/en-us/"),
        _bannerCard("assets/others/val_banner_2.webp", "https://www.riotgames.com/en"),
        _bannerCard("assets/others/twitch_image.jpeg", "https://www.twitch.tv/valorant"),
        _bannerCard("assets/others/valorant_news.jpeg", "https://playvalorant.com/en-us/news/"),
        _bannerCard("assets/others/valorant_media.jpg", "https://playvalorant.com/en-us/media/"),
      ],
      options: CarouselOptions(
        height: 200,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.9,
      ),
    );
  }
}

/// ---------------------------
/// TOP PICKS SECTION
/// ---------------------------

/// Displays a paginated, responsive grid of product cards.
///
/// Each product card shows:
/// - Product image and name
/// - Description or category
/// - Price and like button
///
/// Supports pagination and user interaction for liking/unliking products.
class TopPicksSection extends StatefulWidget {
  /// The list of products to be displayed.
  final List<Map<String, String>> products;

  /// Callback to add a product to favorites.
  final Future<void> Function(Map<String, String>) addFavorite;

  /// Callback to remove a product from favorites.
  final Future<void> Function(Map<String, String>) removeFavorite;

  const TopPicksSection({
    super.key,
    required this.products,
    required this.addFavorite,
    required this.removeFavorite,
  });

  @override
  State<TopPicksSection> createState() => _TopPicksSectionState();
}

class _TopPicksSectionState extends State<TopPicksSection> {
  /// The currently active pagination page index.
  int _currentPage = 0;

  /// Determines the number of items per row based on screen width.
  int itemsPerRow(double width) => (width ~/ 160).clamp(1, 5);

  /// Calculates the total number of pages for pagination.
  int get totalPages {
    final screenWidth = MediaQuery.of(context).size.width;
    final perRow = itemsPerRow(screenWidth);
    final itemsPerPage = perRow * 3;
    return (widget.products.length / itemsPerPage).ceil();
  }

  /// Returns the list of products visible on the current page.
  List<Map<String, String>> visibleProducts(double width) {
    final perRow = itemsPerRow(width);
    final itemsPerPage = perRow * 3;
    final startIndex = _currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, widget.products.length);
    return widget.products.sublist(startIndex, endIndex);
  }

  /// Switches pagination to a specific [page].
  void goToPage(int page) => setState(() => _currentPage = page);

  /// Builds a single product card widget.
  ///
  /// Tapping a card navigates to the [ProductPage].
  /// The favorite icon allows toggling between liked and unliked states.
  Widget _productCard(Map<String, String> product) {
    final isLiked = likedProducts.contains(product["id"]);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductPage(product: product)),
        );
      },
      child: Container(
        width: 150,
        height: 230,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: SafeImage(
                product["image"] ?? "assets/others/image_not_found.png",
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              product["name"] ?? "",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Flexible(
              flex: 2,
              child: Text(
                product["desc"] ?? product["category"] ?? "",
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  product["price"] ?? "",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                GestureDetector(
                  onTap: () async {
                    if (isLiked) {
                      await widget.removeFavorite(product);
                    } else {
                      await widget.addFavorite(product);
                    }
                  },
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.redAccent : Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final perRow = itemsPerRow(screenWidth);
    final productsToShow = visibleProducts(screenWidth);

    final gridWidth = perRow * 160 + (perRow - 1) * 6.0;
    final isWideScreen = screenWidth > gridWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            "TOP PICKS FOR YOU",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Center(
          child: SizedBox(
            width: isWideScreen ? gridWidth : double.infinity,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 6,
              runSpacing: 6,
              children: productsToShow.map(_productCard).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 🔹 Pagination buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalPages, (index) {
            final isActive = index == _currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.redAccent : Colors.red.shade900,
                  minimumSize: const Size(40, 32),
                ),
                onPressed: () => goToPage(index),
                child: Text('${index + 1}'),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
