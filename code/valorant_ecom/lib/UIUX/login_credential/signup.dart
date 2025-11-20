// ==============================
// SIGNUP.DART
// User Registration Page for E-Commerce App with Inline Validation
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart'; // Redirect to login after successful registration

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  // Inline validation messages
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  // ==============================
  // VALIDATION FUNCTIONS
  // ==============================

  // Name must have at least 2 words, each at least 2 letters
  bool _isValidName(String name) {
    final words = name.trim().split(' ');
    if (words.length < 2) return false;
    for (var word in words) {
      if (word.length < 2 || !RegExp(r'^[A-Za-z]+$').hasMatch(word)) {
        return false;
      }
    }
    return true;
  }

  // Basic email validation
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  // Password 6-8 chars, at least 1 uppercase, 1 number, 1 symbol
  bool _isValidPassword(String password) {
    final passwordRegex =
        RegExp(r'^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{6,8}$');
    return passwordRegex.hasMatch(password);
  }

  void _validateFields() {
    setState(() {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      _nameError = name.isEmpty
          ? "Name is required"
          : (!_isValidName(name) ? "Enter a valid full name" : null);

      _emailError = email.isEmpty
          ? "Email is required"
          : (!_isValidEmail(email) ? "Enter a valid email address" : null);

      _passwordError = password.isEmpty
          ? "Password is required"
          : (!_isValidPassword(password)
              ? "6-8 chars, 1 uppercase, 1 number, 1 symbol"
              : null);

      _confirmPasswordError = confirmPassword.isEmpty
          ? "Confirm your password"
          : (password != confirmPassword ? "Passwords do not match" : null);
    });
  }

  // ==============================
  // SIGN-UP METHOD
  // ==============================

  Future<void> _signUp() async {
    _validateFields();

    if (_nameError != null ||
        _emailError != null ||
        _passwordError != null ||
        _confirmPasswordError != null) {
      return; // don't proceed if validation failed
    }

    setState(() => _loading = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
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
              // App Logo
              Image.asset(
                "assets/others/val_logo.jpg",
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),

              // Page Title
              const Text(
                "Create Account ✨",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              const Text(
                "Join us and start shopping today!",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),

              // Full Name
              TextField(
                controller: _nameController,
                onChanged: (_) => _validateFields(),
                decoration: InputDecoration(
                  labelText: "Full Name",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _nameError,
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailController,
                onChanged: (_) => _validateFields(),
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _emailError,
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                onChanged: (_) => _validateFields(),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _passwordError,
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                controller: _confirmPasswordController,
                onChanged: (_) => _validateFields(),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _confirmPasswordError,
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 25),

              // Sign-Up Button or Loader
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

              // Navigate to Login
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
