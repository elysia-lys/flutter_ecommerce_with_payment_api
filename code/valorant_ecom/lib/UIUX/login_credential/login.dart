import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valo/UIUX/pages/mainpage.dart';

import 'signup.dart';

/// 🔐 **LoginPage**
/// 
/// This widget provides a secure login interface for users. It handles user
/// authentication by verifying credentials stored in Firebase Firestore and
/// managing session persistence using `SharedPreferences`.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// 🔒 **_LoginPageState**
/// 
/// Manages the state and behavior of the `LoginPage`, including:
/// - Reading user input (name, email, password)
/// - Validating credentials against Firestore
/// - Updating user login status
/// - Storing session information locally
class _LoginPageState extends State<LoginPage> {
  /// Firestore instance used for reading/writing user data.
  final _firestore = FirebaseFirestore.instance;

  /// Controllers for text fields.
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Indicates if the login process is currently ongoing.
  bool _loading = false;

  /// ✅ **Performs user login**
  ///
  /// This method:
  /// 1. Validates the input fields.
  /// 2. Retrieves the user document from Firestore.
  /// 3. Compares entered password with the stored password.
  /// 4. Updates the `loggedIn` field in Firestore.
  /// 5. Saves login session locally using `SharedPreferences`.
  /// 6. Redirects to the `MainPage` upon success.
  Future<void> _login() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 🔸 Basic input validation
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final userId = "${name}_$email"; // Construct a unique user identifier
      final docRef = _firestore.collection('users').doc(userId);
      final docSnap = await docRef.get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        final storedPassword = data['password'];

        // ✅ Validate password
        if (storedPassword == password) {
          await docRef.update({'loggedIn': true}); // Update login flag in Firestore

          // ✅ Store login info locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('loggedInUser', userId);

          // ✅ Navigate to MainPage
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
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Incorrect password")),
          );
        }
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No account found")),
        );
      }
    } catch (e) {
      // ⚠️ Handle login or network errors
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  /// 🧱 **Builds the login page UI**
  ///
  /// Displays input fields for full name, email, and password along with
  /// a login button and navigation to the sign-up page.
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

              // 🔹 Login Button (shows loader while processing)
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
                              fontSize: 18, fontWeight: FontWeight.bold),
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

