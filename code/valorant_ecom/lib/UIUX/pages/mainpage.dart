// ==============================
// MAINPAGE.DART
// Flutter Main Page for E-Commerce Demo
// ==============================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart'; // For carousel banner
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore database
import 'package:url_launcher/url_launcher.dart'; // To open external links
import 'package:valo/UIUX/layout/layout.dart'; // Shared layout for consistent app UI
import 'package:valo/UIUX/login_credential/login.dart'; // Login page
import 'package:valo/main.dart'; // For SafeImage
import 'product.dart'; // Product page

// ==============================
// GLOBAL VARIABLES
// ==============================

/// A set containing IDs of products that the user has liked.
Set<String> likedProducts = {};

// ==============================
// MAIN PAGE WIDGET
// ==============================

/// MainPage represents the dashboard after login.
///
/// Displays:
/// - Banner section with clickable promotions
/// - Top Picks section (products)
/// - Handles favorites (like/unlike)
/// - Checks user login status and loads data from Firestore
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  /// Currently logged-in user ID
  String? userId;

  /// All loaded products from Firestore
  List<Map<String, String>> products = [];

  /// Top Picks products to show on dashboard
  List<Map<String, String>> topPicks = [];

  /// Loading indicators
  bool isLoadingProducts = true;
  bool isCheckingLogin = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Check if user is logged in on init
  }

  // ==============================
  // LOGIN STATUS
  // ==============================

  /// Checks whether a user is logged in by querying Firestore.
  ///
  /// - If a logged-in user is found:
  ///   - Sets userId
  ///   - Loads products and favorites
  /// - Otherwise, navigates to LoginPage
  Future<void> _checkLoginStatus() async {
    try {
      // Get all users from Firestore
      final snapshot = await FirebaseFirestore.instance.collection('users').get();

      // Filter logged-in user
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() {
          userId = loggedInUser.id;
          isCheckingLogin = false;
        });

        // Load products and user's favorites
        await _loadProducts();
        await _loadFavorites();
      } else {
        // No logged-in user → redirect to login
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

  // ==============================
  // LOAD PRODUCTS
  // ==============================

  /// Loads products from Firestore and prepares Top Picks.
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

        // Prepare Top Picks by shuffling and limiting to 20
        topPicks = List<Map<String, String>>.from(loaded)..shuffle();
        if (topPicks.length > 20) topPicks = topPicks.sublist(0, 20);

        isLoadingProducts = false;
      });
    } catch (e) {
      debugPrint('Firestore load error: $e');
      setState(() => isLoadingProducts = false);
    }
  }

  // ==============================
  // FAVORITES (LIKED PRODUCTS)
  // ==============================

  /// Loads user's favorite products from Firestore
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

  /// Add product to favorites
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

  /// Remove product from favorites
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

  // ==============================
  // BACK BUTTON HANDLING
  // ==============================

  /// Handles Android back button.
  ///
  /// - If not at root → default back navigation
  /// - If at root → show exit confirmation dialog
  Future<bool> _onWillPop() async {
    if (Navigator.of(context).canPop()) {
      return true; // Not root, allow back
    }

    // Root → show exit confirmation
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit App"),
        content: const Text("Are you sure you want to exit the app?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Yes")),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  // ==============================
  // BUILD WIDGET
  // ==============================

  @override
  Widget build(BuildContext context) {
    // Show loader while checking login
    if (isCheckingLogin) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: AppLayout(
        title: '', // No title in AppBar
        appBarActions: [], // Can add actions here
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BannerSection(), // Carousel banners
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
                    child: Text("No products found.", style: TextStyle(color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================
// BANNER SECTION
// ==============================

/// Carousel banners at top of main page
class BannerSection extends StatelessWidget {
  const BannerSection({super.key});

  /// Launch external URL
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  /// Banner card widget
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

// ==============================
// TOP PICKS SECTION
// ==============================

/// Displays the Top Picks products with pagination and favorites
class TopPicksSection extends StatefulWidget {
  final List<Map<String, String>> products;
  final Future<void> Function(Map<String, String>) addFavorite;
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
  /// Current page in pagination
  int _currentPage = 0;

  /// Calculate number of items per row based on screen width
  int itemsPerRow(double width) => (width ~/ 160).clamp(1, 5);

  /// Total pages based on items per page
  int get totalPages {
    final screenWidth = MediaQuery.of(context).size.width;
    final perRow = itemsPerRow(screenWidth);
    final itemsPerPage = perRow * 3;
    return (widget.products.length / itemsPerPage).ceil();
  }

  /// Get visible products for current page
  List<Map<String, String>> visibleProducts(double width) {
    final perRow = itemsPerRow(width);
    final itemsPerPage = perRow * 3;
    final startIndex = _currentPage * itemsPerPage;
    final endIndex = (startIndex + itemsPerPage).clamp(0, widget.products.length);
    return widget.products.sublist(startIndex, endIndex);
  }

  /// Go to specific page in pagination
  void goToPage(int page) => setState(() => _currentPage = page);

  /// Individual product card
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

  // ==============================
  // BUILD TOP PICKS
  // ==============================

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
