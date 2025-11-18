// ==============================
// LOGIN.DART
// User Authentication Page for E-Commerce App
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valo/UIUX/pages/mainpage.dart'; // Redirect after successful login
import 'signup.dart'; // Navigate to sign-up page

// ==============================
// LOGIN PAGE WIDGET
// ==============================

/// 🔐 **LoginPage**
///
/// Provides a secure login interface for users. Handles:
/// - User input for full name, email, and password
/// - Authentication against Firebase Firestore
/// - Session persistence via SharedPreferences
/// - Navigation to the [MainPage] on successful login
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// ==============================
// LOGIN PAGE STATE
// ==============================

/// 🔒 **_LoginPageState**
///
/// Manages UI and business logic for the login process:
/// - Reads and validates user input
/// - Checks credentials against Firestore
/// - Updates login status in Firestore
/// - Stores session information locally
/// - Handles navigation and error messages
class _LoginPageState extends State<LoginPage> {
  /// Firestore instance for reading/writing user data
  final _firestore = FirebaseFirestore.instance;

  /// Controllers for input fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Indicates whether a login process is ongoing
  bool _loading = false;

  // ==============================
  // LOGIN METHOD
  // ==============================

  /// ✅ Performs user login
  ///
  /// Steps:
  /// 1. Validate input fields (full name, email, password)
  /// 2. Construct a unique Firestore document ID
  /// 3. Retrieve the user document from `users` collection
  /// 4. Compare input password with stored password
  /// 5. Update `loggedIn` field in Firestore
  /// 6. Store user session in `SharedPreferences`
  /// 7. Navigate to [MainPage] if login is successful
  Future<void> _login() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 🔹 Basic input validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Construct a unique user ID from name + email
      final userId = "${name}_$email";
      final docRef = _firestore.collection('users').doc(userId);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        final storedPassword = data['password'];

        // ✅ Password validation
        if (storedPassword == password) {
          // Mark user as logged in in Firestore
          await docRef.update({'loggedIn': true});

          // ✅ Store session locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('loggedInUser', userId);

          // ✅ Show success message and navigate to main page
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Login successful!")),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainPage()),
            );
          }
        } else {
          // 🔹 Wrong password
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Incorrect password")),
          );
        }
      } else {
        // 🔹 User not found
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No account found")),
        );
      }
    } catch (e) {
      // ⚠️ Handle errors (network issues, Firestore errors)
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // ==============================
  // BUILD METHOD
  // ==============================

  /// 🧱 Builds the LoginPage UI
  ///
  /// Includes:
  /// - App logo and welcome text
  /// - Input fields for full name, email, and password
  /// - Login button with loading indicator
  /// - Navigation link to Sign-Up page
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔹 App Logo
              Image.asset(
                "assets/others/val_logo.jpg",
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),

              // 🔹 Greeting Text
              const Text(
                "Welcome Back 👋",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Login to continue shopping",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),

              // 🔸 Full Name Field
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),

              // 🔸 Email Field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),

              // 🔸 Password Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 25),

              // 🔹 Login Button / Loader
              _loading
                  ? const CircularProgressIndicator(color: Colors.redAccent)
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _login,
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),

              // 🔹 Sign-Up Navigation
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  );
                },
                child: const Text(
                  "Don't have an account? Sign up",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
