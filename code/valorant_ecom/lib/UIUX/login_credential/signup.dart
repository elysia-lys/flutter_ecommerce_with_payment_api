// ==============================
// SIGNUP.DART
// User Registration Page for E-Commerce App
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart'; // Redirect to login after successful registration

// ==============================
// SIGN-UP PAGE WIDGET
// ==============================

/// 🔐 **SignUpPage**
///
/// Provides a user interface for new users to create an account. Features:
/// - Input fields for Full Name, Email, and Password
/// - Integration with Firebase Firestore to store user credentials
/// - Loading indicator during registration
/// - Redirects to [LoginPage] on successful registration
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

// ==============================
// SIGN-UP PAGE STATE
// ==============================

/// 🔒 **_SignUpPageState**
///
/// Manages state and behavior for the sign-up process, including:
/// - Form input management with TextEditingControllers
/// - Validation of user input
/// - Firestore integration to create new user document
/// - Displaying SnackBars for success and error messages
/// - Navigation to [LoginPage] after registration
class _SignUpPageState extends State<SignUpPage> {
  /// Firestore instance for user data storage
  final _firestore = FirebaseFirestore.instance;

  /// Controller for Full Name input field
  final _nameController = TextEditingController();

  /// Controller for Email input field
  final _emailController = TextEditingController();

  /// Controller for Password input field
  final _passwordController = TextEditingController();

  /// Indicates whether a sign-up process is ongoing
  bool _loading = false;

  // ==============================
  // SIGN-UP METHOD
  // ==============================

  /// ✅ Handles user registration
  ///
  /// Steps:
  /// 1. Validate that all input fields are filled
  /// 2. Construct a unique Firestore document ID (`name_email`)
  /// 3. Create a new document in `users` collection with user details
  /// 4. Show success message via SnackBar
  /// 5. Navigate to [LoginPage] on successful registration
  /// 6. Show error SnackBar if Firestore operation fails
  Future<void> _signUp() async {
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
      // Construct a unique user ID
      final userId = "${name}_$email";

      // Create user document in Firestore
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'password': password,
        'loggedIn': false,
        'createdAt': DateTime.now(),
      });

      // ✅ Show success message and navigate to login page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully!")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      // ⚠️ Handle Firestore errors
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

  /// 🧱 Builds the SignUpPage UI
  ///
  /// Includes:
  /// - App logo and welcome text
  /// - Input fields for Full Name, Email, and Password
  /// - Sign-up button with loading indicator
  /// - Navigation link to [LoginPage] for existing users
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
              /// 🔹 App Logo
              Image.asset(
                "assets/others/val_logo.jpg",
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),

              /// 🔹 Page Title
              const Text(
                "Create Account ✨",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              /// 🔹 Subtitle
              const Text(
                "Join us and start shopping today!",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),

              /// 🔸 Full Name Input
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

              /// 🔸 Email Input
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

              /// 🔸 Password Input
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

              /// 🔹 Sign-Up Button or Loading Spinner
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
                        onPressed: _signUp,
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),

              /// 🔹 Navigate to Login Page
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Text(
                  "Already have an account? Login",
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
