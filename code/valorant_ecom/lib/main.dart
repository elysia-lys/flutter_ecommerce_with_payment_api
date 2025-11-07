import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:valo/UIUX/pages/mainpage.dart';
import 'UIUX/login_credential/login.dart';

/// Entry point of the Flutter application.
/// 
/// This function ensures Flutter bindings are initialized before Firebase.
/// It initializes Firebase, then launches the main app widget [MyApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

/// Root widget of the application.
/// 
/// Configures the global theme, disables the debug banner, 
/// and sets [AuthCheck] as the home screen to determine 
/// whether a user is already logged in.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-Commerce Demo',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark,
      ),
      home: const AuthCheck(),
    );
  }
}

/// A stateful widget that determines the user's authentication status.
///
/// The widget checks both:
/// 1. Local storage (via [SharedPreferences]) for a previously logged-in user.
/// 2. Firestore collection for a user document with `'loggedIn': true`.
///
/// Based on these checks, it redirects to either [MainPage] (if logged in)
/// or [LoginPage] (if not).
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  /// Indicates whether the login check is still in progress.
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// Checks the login status of the current user.
  ///
  /// This method:
  /// - First waits briefly to maintain a black screen (smooth transition).
  /// - Reads local data from [SharedPreferences] for a saved user ID.
  /// - If not found, queries Firestore for any user with `'loggedIn' == true'`.
  /// - Navigates to the appropriate page based on the results.
  Future<void> _checkLoginStatus() async {
    try {
      // 🕑 Short delay ensures the splash screen remains briefly visible.
      await Future.delayed(const Duration(milliseconds: 300));

      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('loggedInUser');

      if (savedUserId != null) {
        // ✅ User found locally — navigate to main dashboard.
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
        }
        return;
      }

      // 🔹 No local session — check Firestore for a logged-in record.
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('loggedIn', isEqualTo: true)
          .limit(1)
          .get();

      final loggedIn = snapshot.docs.isNotEmpty;

      // ✅ Navigate to appropriate screen depending on Firestore result.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => loggedIn ? const MainPage() : const LoginPage(),
          ),
        );
      }
    } catch (e) {
      // ⚠️ Any error encountered will fallback to the login page.
      debugPrint('⚠️ Error checking login status: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } finally {
      // 🖤 Mark completion of status checking to remove black overlay.
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🖤 Display a pure black screen while checking to avoid flicker.
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
      );
    }

    // 🔁 Fallback — should not be displayed unless state is inconsistent.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
    );
  }
}

/// A utility widget for safely loading images from either
/// local assets or network URLs.
///
/// Provides graceful error handling by falling back to a placeholder image
/// when the target asset or network image fails to load.
///
/// Example usage:
/// ```dart
/// SafeImage('assets/images/product.png', fit: BoxFit.cover);
/// SafeImage('https://example.com/image.jpg', width: 100);
/// ```
class SafeImage extends StatelessWidget {
  /// The path or URL of the image.
  final String path;

  /// How the image should be inscribed into the space allocated.
  final BoxFit fit;

  /// Optional width of the image.
  final double? width;

  /// Optional height of the image.
  final double? height;

  /// Creates a [SafeImage] widget.
  ///
  /// The [path] can be either a local asset path or a network URL.
  /// If loading fails, a default placeholder will be displayed.
  const SafeImage(
    this.path, {
    super.key,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Default placeholder image for missing or invalid resources.
    const placeholder = "assets/others/image_not_found.png";

    // If path is a network URL, use Image.network with fallback.
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

    // Otherwise, attempt to load a local asset image.
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
