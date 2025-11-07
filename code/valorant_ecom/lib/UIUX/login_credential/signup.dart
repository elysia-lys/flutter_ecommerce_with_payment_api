import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

/// {@template sign_up_page}
/// A page that allows users to create a new account.
///
/// Features:
/// - Full Name, Email, and Password input fields
/// - Firebase Firestore integration for storing user data
/// - Loading indicator while creating an account
/// - Redirects to [LoginPage] upon successful registration
/// {@endtemplate}
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

/// State class for [SignUpPage].
/// Handles form input, validation, Firestore interaction, and navigation.
class _SignUpPageState extends State<SignUpPage> {
  /// Firebase Firestore instance for user data storage.
  final _firestore = FirebaseFirestore.instance;

  /// Controller for the Full Name input field.
  final _nameController = TextEditingController();

  /// Controller for the Email input field.
  final _emailController = TextEditingController();

  /// Controller for the Password input field.
  final _passwordController = TextEditingController();

  /// Indicates if the sign-up process is in progress.
  bool _loading = false;

  /// Handles the sign-up logic:
  /// 1. Validates that all fields are filled.
  /// 2. Creates a unique user document in Firestore.
  /// 3. Shows success or error messages using SnackBar.
  /// 4. Navigates to [LoginPage] on success.
  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final userId = "${name}_$email";

      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'password': password,
        'loggedIn': false,
        'createdAt': DateTime.now(),
      });

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
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

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
              /// App logo at the top of the sign-up page
              Image.asset(
                "assets/others/val_logo.jpg",
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),

              /// Page title
              const Text(
                "Create Account ✨",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              /// Subtitle description
              const Text(
                "Join us and start shopping today!",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),

              /// Full Name input field
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

              /// Email input field
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

              /// Password input field
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

              /// Sign-up button with loading indicator
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

              /// Navigation to login page
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
