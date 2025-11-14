// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/payment_API/finish_checkout.dart';
import 'package:valo/payment_API/query_transaction.dart';

class PaymentWebView extends StatefulWidget {
  final String checkoutUrl;
  final String txId;
  final String orderId;
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

class _PaymentWebViewState extends State<PaymentWebView> {
  InAppWebViewController? webViewController;
  double progress = 0;

  Timer? pollingTimer;
  int pollAttempts = 0;
  final int maxPollAttempts = 60;
  bool handledResult = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(minutes: 1), _startPolling);
  }

  @override
  void dispose() {
    pollingTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------
  // HARDWARE BACK BUTTON HANDLING
  // ---------------------------------------------
  Future<bool> _onWillPop() async {
    _handlePaymentResult(false); // treat as failed
    return false; // prevent default pop
  }

  // ---------------------------------------------

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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(   // <-- catches phone back button
      onWillPop: _onWillPop,

      child: Scaffold(
        appBar: AppBar(
          title: const Text("Complete Payment"),
          backgroundColor: Colors.black87,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handlePaymentResult(false),
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

            if (progress < 1.0)
              LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}
