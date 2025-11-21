// ==============================
// LOGIN.DART
// User Authentication Page for E-Commerce App
// ==============================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valo/UIUX/pages/mainpage.dart';
import 'package:valo/admin/admin_mainpage.dart';
import 'signup.dart';

// ==============================
// LOGIN PAGE WIDGET
// ==============================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// ==============================
// LOGIN PAGE STATE
// ==============================

class _LoginPageState extends State<LoginPage> {
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;

  // ==============================
  // LOGIN METHOD
  // ==============================

  Future<void> _login() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Empty validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ======================================================
      // 🔥 ADMIN LOGIN OVERRIDE (FIXED USERID)
      // ======================================================
      if (name == "admin" &&
          email == "admin" &&
          password == "admin") {
        final prefs = await SharedPreferences.getInstance();
        // Correct admin ID format
        await prefs.setString('loggedInUser', "admin_admin");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Admin login successful!")),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminMainPage()),
          );
        }
        setState(() => _loading = false);
        return;
      }
      // ======================================================

      // Firestore login for normal users (your original code)
      final userId = "${name}_$email";
      final docRef = _firestore.collection('users').doc(userId);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        final storedPassword = data['password'];

        if (storedPassword == password) {
          await docRef.update({'loggedIn': true});

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('loggedInUser', userId);

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Incorrect password")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No account found")),
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
              Image.asset(
                "assets/others/val_logo.jpg",
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 20),

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
