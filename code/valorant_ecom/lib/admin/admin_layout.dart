import 'package:flutter/material.dart';
import 'package:valo/UIUX/login_credential/login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/admin/admin_mainpage.dart';
import 'package:valo/admin/admin_order_management.dart';
import 'package:valo/admin/admin_product_management.dart';

// ==============================
// ADMIN LAYOUT
// TopBar + Menu Drawer for Admin Panel
// ==============================
class AdminLayout extends StatelessWidget {
  final Widget body;
  final String title;

  const AdminLayout({
    super.key,
    required this.body,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const AdminTopBar(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ==============================
// TOPBAR (WITHOUT SEARCH + CART)
// ==============================
class AdminTopBar extends StatelessWidget {
  const AdminTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 25, 12, 10),
      color: Colors.black,
      child: Row(
        children: [
          // Logo → Back to Admin Main Page
          GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminMainPage()),
              );
            },
            child: Image.asset(
              "assets/others/val_logo.jpg",
              width: 55,
              height: 55,
              fit: BoxFit.cover,
            ),
          ),
          const Spacer(),
          // Menu Button
          const AdminMenuButton(),
        ],
      ),
    );
  }
}

// ==============================
// MENU BUTTON
// ==============================
class AdminMenuButton extends StatelessWidget {
  const AdminMenuButton({super.key});

  void _openMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "AdminMenu",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.6,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color.fromARGB(255, 62, 1, 1).withOpacity(0.92),
                      const Color.fromARGB(255, 2, 2, 41).withOpacity(0.92),
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
                        "Admin Menu",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // ===== MAIN PAGE BUTTON =====
                    _menuItem(
                      context,
                      Icons.home,
                      "Main Page",
                      const AdminMainPage(),
                    ),

                    _menuItem(
                      context,
                      Icons.inventory_2,
                      "Product Management",
                      const AdminProductPage(),
                    ),
                    _menuItem(
                      context,
                      Icons.list_alt,
                      "Order Management",
                      const AdminOrderManagementPage(),
                    ),
                    _menuItem(
                      context,
                      Icons.people,
                      "User Management",
                      const AdminUserPage(),
                    ),
                    _menuItem(
                      context,
                      Icons.shopping_cart_checkout,
                      "Cart Transaction",
                      const AdminCartTransactionPage(),
                    ),

                    const Divider(color: Colors.white54),

                    // Logout
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title:
                          const Text("Logout", style: TextStyle(color: Colors.white)),
                      onTap: () async {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );

                        try {
                          final users = FirebaseFirestore.instance.collection("users");
                          final current =
                              await users.where("loggedIn", isEqualTo: true).get();

                          if (current.docs.isNotEmpty) {
                            await users.doc(current.docs.first.id).update({
                              "loggedIn": false,
                            });
                          }
                        } catch (e) {
                          debugPrint("Logout failed: $e");
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
        return SlideTransition(
          position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
              .animate(animation),
          child: child,
        );
      },
    );
  }

  static ListTile _menuItem(
      BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
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

// ===== Placeholder Pages =====


class AdminUserPage extends StatelessWidget {
  const AdminUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(
        child: Text(
          "User Management Page",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
      ),
    );
  }
}

class AdminCartTransactionPage extends StatelessWidget {
  const AdminCartTransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: const Center(
        child: Text(
          "Cart Transaction Page",
          style: TextStyle(color: Colors.white, fontSize: 22),
        ),
      ),
    );
  }
}
