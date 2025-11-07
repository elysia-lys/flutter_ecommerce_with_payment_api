import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/mainpage.dart';
import 'package:valo/UIUX/pages/product.dart';
import '../layout/layout.dart';
import '../../main.dart'; // SafeImage

/// {@template stationery_page}
/// A page displaying stationery products retrieved from Firestore.
///
/// Features:
/// - Character-based and type-based filtering
/// - Favorite management for logged-in users
/// - Responsive grid layout for product display
/// - Floating action button to toggle filter sidebar
/// {@endtemplate}
class StationeryPage extends StatefulWidget {
  const StationeryPage({super.key});

  /// Stores all stationery items globally for reuse.
  static List<Map<String, String>> allItems = [];

  @override
  State<StationeryPage> createState() => _StationeryPageState();
}

/// State for [StationeryPage].
/// Handles product data loading, filtering, favorites, and user login state.
class _StationeryPageState extends State<StationeryPage> {
  /// All stationery items loaded from Firestore.
  List<Map<String, String>> _allItems = [];

  /// Currently logged-in user's ID.
  String? userId;

  /// Controls visibility of the filter sidebar.
  bool _showFilters = false;

  /// Selected characters for filtering.
  Set<String> _selectedCharacters = {};

  /// Selected stationery types for filtering.
  Set<String> _selectedTypes = {};

  /// Available stationery types for filtering.
  final List<String> _stationeryTypes = [
    'Keychain',
    'Stickers',
    'Badge',
    'Pin',
    'Pen',
    'Poster',
  ];

  /// Character groups by gender and role for filtering.
  final Map<String, Map<String, List<String>>> _characterGroups = {
    'Female': {
      'Sentinels': ['Sage', 'Killjoy', 'Deadlock', 'Vyse'],
      'Duelist': ['Reyna', 'Raze', 'Neon', 'Jett', 'Waylay'],
      'Initiator': ['Skye', 'Fade'],
      'Controller': ['Viper', 'Clove', 'Astra'],
    },
    'Male': {
      'Sentinels': ['Chamber', 'Cypher'],
      'Duelist': ['Iso', 'Yoru', 'Phoenix'],
      'Initiator': ['Tejo', 'Sova', 'Breach', 'Kayo', 'Gekko'],
      'Controller': ['Omen', 'Brimstone', 'Harbor'],
    },
  };

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// Checks if a user is logged in, sets [userId], and loads products and favorites.
  Future<void> _checkLoginStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final docs = snapshot.docs.where((doc) => doc.data()['loggedIn'] == true);
      final loggedInUser = docs.isNotEmpty ? docs.first : null;

      if (loggedInUser != null) {
        setState(() => userId = loggedInUser.id);
        _loadProducts();
        _loadFavorites();
      } else {
        debugPrint("⚠️ No user is logged in.");
      }
    } catch (e) {
      debugPrint('⚠️ Error checking login status: $e');
    }
  }

  /// Loads stationery products from Firestore and filters by category.
  Future<void> _loadProducts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name']?.toString() ?? '',
          'desc': data['desc']?.toString() ?? '',
          'price': data['price']?.toString() ?? '',
          'image': data['image']?.toString() ?? 'assets/image_not_found.png',
          'category': data['category']?.toString() ?? '',
          'type': data['type']?.toString() ?? '',
          'size': data['size']?.toString() ?? '',
          'color': data['color']?.toString() ?? '',
          'measurement': data['measurement']?.toString() ?? '',
        };
      }).where((item) => item['category']?.toLowerCase() == 'stationery').toList();

      setState(() {
        _allItems = items;
        StationeryPage.allItems = _allItems;
      });

      debugPrint('✅ Loaded ${items.length} stationery items from Firestore');
    } catch (e) {
      debugPrint('❌ Error loading stationery: $e');
    }
  }

  /// Loads the user's favorite products from Firestore.
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
      debugPrint('❌ Error loading favorites: $e');
    }
  }

  /// Adds a product to the user's favorites in Firestore.
  Future<void> _addFavorite(Map<String, String> product) async {
    if (userId == null) return;
    final productId = product['id']!;
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

  /// Removes a product from the user's favorites in Firestore.
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

  /// Returns the filtered list of items based on selected characters and types.
  List<Map<String, String>> get _filteredItems {
    return _allItems.where((item) {
      final matchesCharacter = _selectedCharacters.isEmpty ||
          _selectedCharacters.any(
              (c) => item['name']?.toLowerCase().contains(c.toLowerCase()) ?? false);

      final matchesType = _selectedTypes.isEmpty ||
          _selectedTypes.any((t) {
            final name = item['name']?.toLowerCase() ?? '';
            final desc = item['desc']?.toLowerCase() ?? '';
            return name.contains(t.toLowerCase()) || desc.contains(t.toLowerCase());
          });

      return matchesCharacter && matchesType;
    }).toList();
  }

  /// Resets all selected filters.
  void _resetFilters() {
    setState(() {
      _selectedCharacters.clear();
      _selectedTypes.clear();
    });
  }

  /// Builds the filter sidebar UI with character groups and stationery types.
  Widget _buildFilterPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._characterGroups.entries.map((genderEntry) {
            final gender = genderEntry.key;
            final roles = genderEntry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(gender,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                ...roles.entries.map((roleEntry) {
                  return ExpansionTile(
                    title: Text(roleEntry.key,
                        style: const TextStyle(color: Colors.white)),
                    children: roleEntry.value
                        .map((char) => CheckboxListTile(
                              value: _selectedCharacters.contains(char),
                              onChanged: (v) {
                                setState(() {
                                  v!
                                      ? _selectedCharacters.add(char)
                                      : _selectedCharacters.remove(char);
                                });
                              },
                              title: Text(char,
                                  style: const TextStyle(color: Colors.white)),
                              controlAffinity: ListTileControlAffinity.leading,
                            ))
                        .toList(),
                  );
                }),
                const Divider(color: Colors.white38),
              ],
            );
          }),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text("Type",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          ..._stationeryTypes.map((t) => CheckboxListTile(
                value: _selectedTypes.contains(t),
                onChanged: (v) {
                  setState(() {
                    v! ? _selectedTypes.add(t) : _selectedTypes.remove(t);
                  });
                },
                title: Text(t, style: const TextStyle(color: Colors.white)),
                controlAffinity: ListTileControlAffinity.leading,
              )),
          const SizedBox(height: 10),
          Center(
            child: ElevatedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Reset Filters"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final sidebarWidth = isSmallScreen ? screenWidth * 0.5 : 300.0;
    final gridWidth = screenWidth - (_showFilters ? sidebarWidth : 0);
    final crossAxisCount = (gridWidth / 160).floor().clamp(1, 4);
    final itemWidth = gridWidth / crossAxisCount - 8;
    final filteredItems = _filteredItems;

    return Scaffold(
      body: AppLayout(
        title: "Stationery",
        appBarActions: const [],
        body: Row(
          children: [
            if (_showFilters)
              Container(
                width: sidebarWidth,
                padding: const EdgeInsets.all(8),
                color: Colors.black12,
                child: _buildFilterPanel(),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: GridView.builder(
                  itemCount: filteredItems.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: itemWidth / 200,
                  ),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final isLiked = likedProducts.contains(item['id']);
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProductPage(product: Map<String, String>.from(item))),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SafeImage(
                              item['image'] ?? 'assets/image_not_found.png',
                              width: itemWidth / 2,
                              height: 80,
                            ),
                            const SizedBox(height: 6),
                            Flexible(
                              child: Text(
                                item['name'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                item['desc'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item['price'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.redAccent, fontSize: 12)),
                                GestureDetector(
                                  onTap: () async {
                                    if (isLiked) {
                                      await _removeFavorite(item);
                                    } else {
                                      await _addFavorite(item);
                                    }
                                  },
                                  child: Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
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
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        icon: Icon(_showFilters ? Icons.close : Icons.filter_alt),
        label: Text(_showFilters ? "Hide Filters" : "Show Filters"),
        onPressed: () {
          setState(() => _showFilters = !_showFilters);
        },
      ),
    );
  }
}
