/// ==============================
/// PAYMENT_WEBVIEW.DART
/// Payment Gateway WebView & Transaction Handling
/// ==============================
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/payment_API/finish_checkout.dart';
import 'package:valo/payment_API/query_transaction.dart';

/// ==============================
/// PAYMENT WEBVIEW PAGE WIDGET
/// ==============================

/// Stateful widget for displaying a payment gateway web view.
///
/// Responsibilities:
/// - Load checkout URL for payment
/// - Monitor transaction status via polling or URL redirects
/// - Update Firestore order status after payment
/// - Clear purchased items from the user's cart
/// - Navigate to `FinishCheckoutPage` after handling payment
class PaymentWebView extends StatefulWidget {
  /// Checkout URL from payment gateway
  final String checkoutUrl;

  /// Transaction ID for tracking payment
  final String txId;

  /// Firestore order document ID
  final String orderId;

  /// Firestore user ID
  final String userId;

  const PaymentWebView({
    super.key,
    required this.checkoutUrl,
    required this.txId,
    required this.orderId,
    required this.userId,
  });

  @override
  State<PaymentWebView> createState() => _PaymentWebViewState();
}

/// ==============================
/// PAYMENT WEBVIEW PAGE STATE
/// ==============================

/// Maintains state for [PaymentWebView]
/// Handles:
/// - WebView progress and controller
/// - Back button handling
/// - Transaction polling
/// - Cart cleanup
/// - Navigation to FinishCheckoutPage
class _PaymentWebViewState extends State<PaymentWebView> {
  // -----------------------------
  // STATE VARIABLES
  // -----------------------------
  InAppWebViewController? webViewController;
  double progress = 0; // Page loading progress (0–1)

  Timer? pollingTimer;
  int pollAttempts = 0;
  final int maxPollAttempts = 60;
  bool handledResult = false; // Ensure payment result handled once

  // -----------------------------
  // INITIALIZATION
  // -----------------------------
  @override
  void initState() {
    super.initState();
    // Delay before starting polling to give time for redirect
    Future.delayed(const Duration(minutes: 1), _startPolling);
  }

  @override
  void dispose() {
    pollingTimer?.cancel();
    super.dispose();
  }

  // ==============================
  // BACK BUTTON HANDLING
  // ==============================

  /// Handles system back button press
  /// Shows confirmation dialog and treats as failed payment if confirmed
  Future<bool> _onWillPop() async {
    return await _showCancelConfirmation();
  }

  /// Displays a dialog to confirm payment cancellation
  /// Updates order as failed if user confirms
  Future<bool> _showCancelConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Payment"),
        content: const Text("Are you sure you want to cancel payment?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (result == true) {
      _handlePaymentResult(false); // treat as failed
      return false; // prevent automatic pop
    }
    return false; // stay on page
  }

  // ==============================
  // TRANSACTION POLLING
  // ==============================

  /// Starts polling payment API to check transaction status
  /// Stops when payment is confirmed or max attempts reached
  void _startPolling() {
    pollingTimer?.cancel();
    pollAttempts = 0;

    pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      pollAttempts++;

      if (pollAttempts > maxPollAttempts || handledResult) {
        timer.cancel();
        if (!handledResult) _handlePaymentResult(false);
        return;
      }

      try {
        final data = await AmpersandPayQuery.queryTransaction(widget.txId);

        if (data == null || data["ret"] == 1201) {
          debugPrint("⏳ Transaction not yet found, retrying...");
          return;
        }

        final status = data["txStatus"]?.toString().toUpperCase() ?? "";
        debugPrint("🌐 Transaction Status: $status");

        if (status == "SUCCESS" || status == "PAID") {
          timer.cancel();
          _handlePaymentResult(true);
        }
      } catch (e) {
        debugPrint("⚠️ Polling error: $e");
      }
    });
  }

  // ==============================
  // CART CLEANUP
  // ==============================

  /// Removes purchased items from user's cart
  Future<void> _clearCart() async {
    final docRef =
        FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final orderData = doc.data();
    if (orderData == null) return;

    final products =
        List<Map<String, dynamic>>.from(orderData['productList'] ?? []);
    if (products.isEmpty) return;

    final productIds = products.map((p) => p['id'].toString()).toList();

    final cartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cart');

    final cartSnapshot = await cartRef.get();
    for (var doc in cartSnapshot.docs) {
      final cartItem = doc.data();
      final cartItemId =
          cartItem['id']?.toString() ?? cartItem['productId']?.toString();

      if (cartItemId != null && productIds.contains(cartItemId)) {
        await doc.reference.delete();
        debugPrint("🗑️ Deleted cart item: $cartItemId");
      }
    }
  }

  // ==============================
  // PAYMENT RESULT HANDLING
  // ==============================

  /// Updates Firestore order status and navigates to FinishCheckoutPage
  /// Cleans cart if payment was successful
  Future<void> _handlePaymentResult(bool success) async {
    if (handledResult) return;
    handledResult = true;

    pollingTimer?.cancel();

    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
      "status": success ? "paid" : "failed",
      "updatedAt": DateTime.now(),
    });

    if (success) {
      await _clearCart();
    }

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FinishCheckoutPage(
          orderId: widget.orderId,
          txId: widget.txId,
          success: success,
          userId: widget.userId,
        ),
      ),
    );
  }

  // ==============================
  // WIDGET BUILD
  // ==============================

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Complete Payment"),
          backgroundColor: Colors.black87,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _showCancelConfirmation,
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.checkoutUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onProgressChanged: (controller, progressValue) {
                setState(() => progress = progressValue / 100);
              },
              onLoadStop: (controller, url) async {
                if (url == null || handledResult) return;
                final currentUrl = url.toString();
                debugPrint("🌐 Redirected to: $currentUrl");

                if (currentUrl.contains("success") ||
                    currentUrl.contains("completed")) {
                  _handlePaymentResult(true);
                } else if (currentUrl.contains("failed") ||
                    currentUrl.contains("cancel") ||
                    currentUrl.contains("error")) {
                  _handlePaymentResult(false);
                }
              },
            ),
            if (progress < 1.0) LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}
