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

/// Product model for Firestore product entries
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

/// Layout wrapper with TopBar
class AppLayout extends StatelessWidget {
  final Widget body;
  final String title;
  final List<IconButton> appBarActions;

  const AppLayout({
    super.key,
    required this.body,
    required this.title,
    required this.appBarActions,
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

/// TopBar with search, cart, and menu
class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  final TextEditingController _controller = TextEditingController();
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  bool isLoading = true;
  bool isSearching = false;
  DateTime? _lastSearch;

  @override
  void initState() {
    super.initState();
    _loadProductsFromFirestore();

    // Listen to global cart notifier
    cartCountNotifier.addListener(_onCartCountChanged);
  }

  @override
  void dispose() {
    cartCountNotifier.removeListener(_onCartCountChanged);
    super.dispose();
  }

  void _onCartCountChanged() {
    setState(() {}); // Update badge when cart changes
  }

  /// Load all products from Firestore
  Future<void> _loadProductsFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('products').get();
      final products = snapshot.docs.map((doc) => Product.fromFirestore(doc.data())).toList();
      setState(() {
        allProducts = products;
        filteredProducts = products;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Firestore load error: $e');
      setState(() => isLoading = false);
    }
  }

  /// Filter products based on search text (300ms debounce)
  void _filterProducts(String query) {
    final now = DateTime.now();
    _lastSearch = now;

    Future.delayed(const Duration(milliseconds: 300), () {
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

  /// Cart icon with reactive badge
  Widget _buildCartIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            );
          },
          icon: const Icon(Icons.shopping_cart, color: Colors.red, size: 28),
        ),
        if (cartCountNotifier.value > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${cartCountNotifier.value}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 25, 12, 10),
          color: Colors.black,
          child: Row(
            children: [
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
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            hintText: "Search...",
                            hintStyle: TextStyle(color: Colors.white70, fontSize: 14),
                            border: InputBorder.none,
                          ),
                          onChanged: _filterProducts,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _buildCartIcon(),
              const MenuButton(),
            ],
          ),
        ),

        // Search results dropdown
        if (_controller.text.isNotEmpty)
          Container(
            color: Colors.black,
            height: 200,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : isSearching
                    ? const Center(child: Text("Searching...", style: TextStyle(color: Colors.white70)))
                    : filteredProducts.isEmpty
                        ? const Center(child: Text('No products found', style: TextStyle(color: Colors.white70)))
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
                                title: Text(product.name, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(product.desc, style: const TextStyle(color: Colors.white70)),
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

/// Menu button with navigation
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

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
                      const Color.fromARGB(255, 62, 1, 1).withOpacity(0.9),
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
                      child: Text("Menu", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                    _menuItem(context, Icons.home, "Home", const MainPage()),
                    ListTile(
                      leading: const Icon(Icons.category, color: Colors.white),
                      title: const Text("Categories", style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        _openCategoriesMenu(context);
                      },
                    ),
                    const Divider(color: Colors.white54),
                    _menuItem(context, Icons.favorite, "My Favourite", const FavoritePage()),
                    _menuItem(context, Icons.history, "Purchase History", const HistoryPage()),
                    const Divider(color: Colors.white54),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text("Logout", style: TextStyle(color: Colors.white)),
                      onTap: () async {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                        try {
                          final userRef = FirebaseFirestore.instance.collection('users');
                          final loggedInUser = await userRef.where('loggedIn', isEqualTo: true).get();
                          if (loggedInUser.docs.isNotEmpty) {
                            await userRef.doc(loggedInUser.docs.first.id).update({'loggedIn': false});
                          }
                        } catch (e) {
                          debugPrint("Firestore logout update failed: $e");
                        }
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
        final offsetAnimation = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(animation);
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  static ListTile _menuItem(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  void _openCategoriesMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Categories",
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
                      const Color.fromARGB(255, 2, 2, 41).withOpacity(0.95),
                      const Color.fromARGB(255, 62, 1, 1).withOpacity(0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: const [
                    DrawerHeader(
                      child: Text("Categories", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
        final offsetAnimation = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(animation);
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

/// Category list item
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }
}
