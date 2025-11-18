// ==============================
// MAIN.DART
// Flutter E-Commerce Demo Application Entry
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore database
import 'package:shared_preferences/shared_preferences.dart'; // Local storage for session
import 'package:firebase_core/firebase_core.dart'; // Firebase initialization
import 'package:valo/UIUX/pages/mainpage.dart'; // Main dashboard page
import 'UIUX/login_credential/login.dart'; // Login page if user not authenticated

// ==============================
// ENTRY POINT
// ==============================

/// Entry point of the Flutter application.
///
/// Ensures Flutter bindings are initialized before any async operations.
/// Initializes Firebase and launches the root widget [MyApp].
Future<void> main() async {
  // Ensure Flutter engine is initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase services
  await Firebase.initializeApp();

  // Launch the app
  runApp(const MyApp());
}

// ==============================
// ROOT WIDGET
// ==============================

/// Root widget of the application.
///
/// - Configures global theme.
/// - Disables debug banner.
/// - Uses [AuthCheck] to determine initial navigation.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove debug banner
      title: 'E-Commerce Demo',
      theme: ThemeData(
        primarySwatch: Colors.red, // Main color
        brightness: Brightness.dark, // Dark theme globally
      ),
      home: const AuthCheck(), // Initial widget to check login status
    );
  }
}

// ==============================
// AUTHENTICATION CHECK WIDGET
// ==============================

/// Stateful widget that determines whether the user is logged in.
///
/// Checks:
/// 1. Local session in [SharedPreferences].
/// 2. Firestore 'users' collection for any document with `'loggedIn': true`.
///
/// Redirects:
/// - Logged-in users -> [MainPage]
/// - Not logged-in -> [LoginPage]
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  /// Indicates whether the login check is ongoing.
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Start authentication check
  }

  // ==============================
  // LOGIN STATUS CHECK
  // ==============================

  /// Checks if a user is already logged in.
  ///
  /// Steps:
  /// 1. Delay briefly to maintain splash screen visibility.
  /// 2. Check local storage for saved user ID.
  /// 3. If not found, query Firestore for logged-in user.
  /// 4. Navigate to the appropriate page.
  Future<void> _checkLoginStatus() async {
    try {
      // Small delay for smooth splash transition
      await Future.delayed(const Duration(milliseconds: 300));

      // Access local storage
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('loggedInUser');

      if (savedUserId != null) {
        // ✅ User exists locally — navigate to main page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
        }
        return; // Stop further checks
      }

      // 🔹 No local session — check Firestore for logged-in user
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('loggedIn', isEqualTo: true)
          .limit(1) // Only need one document
          .get();

      final loggedIn = snapshot.docs.isNotEmpty;

      // Navigate to MainPage or LoginPage based on Firestore result
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => loggedIn ? const MainPage() : const LoginPage(),
          ),
        );
      }
    } catch (e) {
      // ⚠️ Error handling — fallback to login page
      debugPrint('⚠️ Error checking login status: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } finally {
      // Remove black overlay/loading spinner
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  // ==============================
  // WIDGET BUILD
  // ==============================

  @override
  Widget build(BuildContext context) {
    // Display black screen while login status is being checked
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(), // Fills screen
      );
    }

    // Fallback — display a loading spinner (should rarely appear)
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );
  }
}

// ==============================
// SAFE IMAGE WIDGET
// ==============================

/// Loads images safely from either assets or network.
///
/// - Falls back to a placeholder if image fails to load.
/// - Supports optional width, height, and [BoxFit] properties.
///
/// Example:
/// ```dart
/// SafeImage('assets/images/product.png', fit: BoxFit.cover);
/// SafeImage('https://example.com/image.jpg', width: 100);
/// ```
class SafeImage extends StatelessWidget {
  /// Image source (asset path or network URL)
  final String path;

  /// Image fit inside available space
  final BoxFit fit;

  /// Optional width
  final double? width;

  /// Optional height
  final double? height;

  /// Constructor
  const SafeImage(
    this.path, {
    super.key,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder image if loading fails
    const placeholder = "assets/others/image_not_found.png";

    // Network image loading
    if (path.startsWith("http")) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) =>
            Image.asset(placeholder, fit: fit, width: width, height: height),
      );
    }

    // Local asset image loading
    return Image.asset(
      path.isNotEmpty ? path : placeholder,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, __, ___) =>
          Image.asset(placeholder, fit: fit, width: width, height: height),
    );
  }
}
