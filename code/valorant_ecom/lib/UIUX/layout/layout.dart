import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/UIUX/pages/mainpage.dart'; 
import 'package:valo/UIUX/pages/product.dart';
import '../../main.dart';
import '../pages/favorite.dart';
import '../pages/cart.dart';
import '../category_pages/clothing.dart';
import '../category_pages/fashion_accessories.dart';
import '../category_pages/computer_accessories.dart';
import '../category_pages/bags.dart';
import '../category_pages/stationeries.dart';
import '../category_pages/toys_figurines.dart';
import '../pages/transaction_history/history.dart';
import '../login_credential/login.dart';

/// Represents a single product entry retrieved from Firestore.
/// Each product contains descriptive and classification attributes
/// such as name, description, category, and image. Used across
/// pages including search results, product details, and categories.
class Product {
  final String name;
  final String desc;
  final String price;
  final String category;
  final String type;
  final String size;
  final String color;
  final String measurement;
  final String image;

  /// Creates a [Product] with all required properties.
  const Product({
    required this.name,
    required this.desc,
    required this.price,
    required this.category,
    required this.type,
    required this.size,
    required this.color,
    required this.measurement,
    required this.image,
  });

  /// Factory constructor for building a [Product] object from a Firestore document.
  factory Product.fromFirestore(Map<String, dynamic> data) {
    return Product(
      name: data['name'] ?? '',
      desc: data['desc'] ?? '',
      price: data['price'] ?? '',
      category: data['category'] ?? '',
      type: data['type'] ?? '',
      size: data['size'] ?? '',
      color: data['color'] ?? '',
      measurement: data['measurement'] ?? '',
      image: data['image'] ?? '',
    );
  }
}

/// Provides a consistent layout wrapper for app pages.
///
/// Includes a top navigation bar ([TopBar]) and dynamic [body] content.
/// Used to maintain consistent visual structure across the app.
class AppLayout extends StatelessWidget {
  final Widget body;

  const AppLayout({
    super.key,
    required this.body,
    required List<IconButton> appBarActions,
    required String title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const TopBar(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Displays the top navigation bar with a logo, search bar, cart, and menu.
///
/// The [TopBar] also implements Firestore search functionality with
/// a debounced filter for products by name or description.
class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final TextEditingController _controller = TextEditingController();

  /// List of all products fetched from Firestore.
  List<Product> allProducts = [];

  /// Filtered list of products based on search input.
  List<Product> filteredProducts = [];

  /// Indicates if product data is currently being loaded.
  bool isLoading = true;

  /// Indicates if the system is actively filtering products.
  bool isSearching = false;

  /// Tracks the most recent search input timestamp for debouncing.
  DateTime? _lastSearch;

  @override
  void initState() {
    super.initState();
    _loadProductsFromFirestore();
  }

  /// Loads all product data from Firestore's `products` collection.
  ///
  /// The products are cached locally in [allProducts] to avoid repeated
  /// Firestore reads during search filtering.
  Future<void> _loadProductsFromFirestore() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('products').get();

      final products =
          snapshot.docs.map((doc) => Product.fromFirestore(doc.data())).toList();

      setState(() {
        allProducts = products;
        filteredProducts = products;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Firestore load error: $e');
      setState(() => isLoading = false);
    }
  }

  /// Applies a 300 ms debounce before filtering products by query text.
  ///
  /// This improves performance and avoids over-triggering on every keystroke.
  void _filterProducts(String query) {
    final now = DateTime.now();
    _lastSearch = now;

    Future.delayed(const Duration(milliseconds: 300), () {
      // Only execute the latest queued search
      if (_lastSearch == now) {
        final search = query.toLowerCase();
        setState(() => isSearching = true);

        final results = allProducts.where((product) {
          return product.name.toLowerCase().contains(search) ||
              product.desc.toLowerCase().contains(search);
        }).toList();

        setState(() {
          filteredProducts = results;
          isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// Top navigation row: logo, search bar, and action icons.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 25, 12, 10),
          color: Colors.black,
          child: Row(
            children: [
              /// App logo that navigates to [MainPage] on tap.
              GestureDetector(
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainPage()),
                    (route) => false,
                  );
                },
                child: const SafeImage(
                  "assets/others/val_logo.jpg",
                  width: 55,
                  height: 55,
                ),
              ),

              /// Search input bar for quick product lookup.
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 8),
                            hintText: "Search...",
                            hintStyle:
                                TextStyle(color: Colors.white70, fontSize: 14),
                            border: InputBorder.none,
                          ),
                          onChanged: _filterProducts,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// Cart and menu buttons.
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart,
                        color: Colors.red, size: 28),
                  ),
                  const MenuButton(),
                ],
              ),
            ],
          ),
        ),

        /// Displays search results below the top bar when query is active.
        if (_controller.text.isNotEmpty)
          Container(
            color: Colors.black,
            height: 200,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : isSearching
                    ? const Center(
                        child: Text("Searching...",
                            style: TextStyle(color: Colors.white70)))
                    : filteredProducts.isEmpty
                        ? const Center(
                            child: Text('No products found',
                                style: TextStyle(color: Colors.white70)))
                        : ListView.builder(
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              final imagePath = product.image.trim();

                              return ListTile(
                                leading: SafeImage(
                                  imagePath.isNotEmpty
                                      ? imagePath
                                      : "assets/others/image_not_found.png",
                                  width: 40,
                                  height: 40,
                                ),
                                title: Text(product.name,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                subtitle: Text(product.desc,
                                    style: const TextStyle(
                                        color: Colors.white70)),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductPage(product: {
                                        "name": product.name,
                                        "desc": product.desc,
                                        "price": product.price,
                                        "category": product.category,
                                        "type": product.type,
                                        "size": product.size,
                                        "color": product.color,
                                        "measurement": product.measurement,
                                        "image": imagePath,
                                      }),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
          ),
      ],
    );
  }
}

/// Displays the app’s main side menu with navigation and logout options.
///
/// The [MenuButton] opens a sliding drawer containing navigation links
/// to home, favorites, purchase history, and product categories.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  /// Opens the left slide-in menu panel.
  void _openMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Menu",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.6,
            heightFactor: 1.0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      // ignore: deprecated_member_use
                      const Color.fromARGB(255, 62, 1, 1).withOpacity(0.9),
                      // ignore: deprecated_member_use
                      const Color.fromARGB(255, 2, 2, 41).withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const DrawerHeader(
                      child: Text(
                        "Menu",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    /// Home and categories
                    _menuItem(context, Icons.home, "Home", const MainPage()),
                    ListTile(
                      leading:
                          const Icon(Icons.category, color: Colors.white),
                      title: const Text("Categories",
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        _openCategoriesMenu(context);
                      },
                    ),

                    const Divider(color: Colors.white54),

                    /// Favorites and purchase history
                    _menuItem(context, Icons.favorite, "My Favourite",
                        const FavoritePage()),
                    _menuItem(context, Icons.history, "Purchase History",
                        const HistoryPage()),

                    const Divider(color: Colors.white54),

                    /// Logout button with immediate navigation
                    ListTile(
                      leading: const Icon(Icons.logout,
                          color: Colors.redAccent),
                      title: const Text("Logout",
                          style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginPage()),
                          (route) => false,
                        );

                        // Background Firestore update for logout status
                        Future(() async {
                          try {
                            final userRef = FirebaseFirestore.instance
                                .collection('users');
                            final loggedInUser = await userRef
                                .where('loggedIn', isEqualTo: true)
                                .get();

                            if (loggedInUser.docs.isNotEmpty) {
                              await userRef
                                  .doc(loggedInUser.docs.first.id)
                                  .update({'loggedIn': false});
                            }
                          } catch (e) {
                            debugPrint(
                                "⚠️ Firestore logout update failed: $e");
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
                begin: const Offset(-1, 0), end: Offset.zero)
            .animate(animation);
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  /// Creates a reusable list tile for menu navigation.
  static ListTile _menuItem(
      BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  /// Opens the left-side category drawer listing all product categories.
void _openCategoriesMenu(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Categories",
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerLeft, // changed from right to left
        child: FractionallySizedBox(
          widthFactor: 0.6,
          heightFactor: 1.0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    // ignore: deprecated_member_use
                    const Color.fromARGB(255, 2, 2, 41).withOpacity(0.95),
                    // ignore: deprecated_member_use
                    const Color.fromARGB(255, 62, 1, 1).withOpacity(0.95),
                  ],
                  begin: Alignment.topLeft, // updated for left alignment
                  end: Alignment.bottomRight,
                ),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: const [
                  DrawerHeader(
                    child: Text(
                      "Categories",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _CategoryItem(Icons.checkroom, "Clothing", ClothingPage()),
                  _CategoryItem(Icons.watch, "Fashion Accessories", FashionAccessoryPage()),
                  _CategoryItem(Icons.computer, "Computer & Accessories", ComputerAccessoryPage()),
                  _CategoryItem(Icons.shopping_bag, "Bags", BagsPage()),
                  _CategoryItem(Icons.edit, "Stationeries", StationeryPage()),
                  _CategoryItem(Icons.toys, "Toys & Figurines", ToyFigurinesPage()),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(-1, 0), // start from left instead of right
        end: Offset.zero,
      ).animate(animation);
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu, color: Colors.red, size: 26),
      onPressed: () => _openMenu(context),
    );
  }
}

/// Reusable list tile for category navigation within the category menu.
///
/// Each [_CategoryItem] links to a specific product category page.
class _CategoryItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget page;

  const _CategoryItem(this.icon, this.title, this.page);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }
}
