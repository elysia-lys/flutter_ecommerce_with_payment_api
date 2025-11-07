/*
============================================================
File: call_api.dart
Author: Liew Yee Shian
Project: Flutter IPG Integration (AmpersandPay)
Description:
  This file defines the CallApi class, which handles secure 
  communication between the Flutter app and the AmpersandPay 
  IPG (Internet Payment Gateway) API. It processes payment 
  requests, generates SHA-512 signatures, sends data via HTTPS, 
  and stores transaction details (txId, status, timestamps, 
  userId) in Firebase Firestore.

Key Responsibilities:
  • Build and sign payment request payloads.
  • Send transactions to AmpersandPay’s sandbox/staging endpoint.
  • Handle API responses and extract checkout URLs.
  • Save transaction info to Firestore for record tracking.
  • Support multiple payment channels (Credit Card, Online Banking, E-Wallet).

Usage Notes:
  - Ensure that `cloud_firestore`, `http`, and `crypto` 
    dependencies are included in pubspec.yaml.
  - The class can be used by calling:
        await CallApi.processPayment(...);
  - Suitable for integration in checkout or order confirmation flows.
============================================================
*/

import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Import Firestore

/// The CallApi class handles payment request logic for the Flutter app.
/// It connects to the AmpersandPay IPG API and saves transaction data to Firestore.
class CallApi {
  // Merchant credentials provided by AmpersandPay
  static const String merchantId = "91012387";
  static const String integrationKey =
      "8c72119782094d0ea1972f10d597046e934732fb86500e4dad52e068938e5b16";
  static const String apiUrl = "https://stg-ipg.ampersandpay.com/tx/request";

  /// Maps the user's selected payment method to AmpersandPay's specific channel code.
  static String _getChannelCode(String method) {
    switch (method) {
      case "Online Banking":
        return "DD"; // Direct Debit
      case "Credit Card":
        return "CC"; // Credit Card
      case "E-Wallet":
        return "EW"; // E-Wallet
      default:
        return "CC"; // Default fallback
    }
  }

  /// Generates a SHA-512 signature required by AmpersandPay API.
  /// The signature ensures secure and verified data transmission.
  static String _generateSignature(String jsonString) {
    final bytes = utf8.encode(jsonString + integrationKey);
    final digest = sha512.convert(bytes);
    return digest.toString();
  }

  /// Processes the payment request by:
  /// 1. Preparing the payload.
  /// 2. Sending it to the AmpersandPay API.
  /// 3. Handling the API response.
  /// 4. Storing transaction data (txId, status) in Firestore.
  static Future<Map<String, dynamic>?> processPayment({
    required double totalAmount, // Total payment amount
    required String paymentMethod, // Selected payment method
    required List<Map<String, dynamic>> items, // Product list
    required Map<String, dynamic> userInfo, // Customer info (name, email, phone)
    required String orderId, // Unique order identifier
    required String userId, // Logged-in user's Firestore ID
  }) async {
    try {
      // Convert Flutter method name into IPG channel code
      final txChannel = _getChannelCode(paymentMethod);

      // ✅ Build JSON payload following AmpersandPay API specifications
      final Map<String, dynamic> payload = {
        "merchantId": merchantId,
        "txType": "SALE", // Transaction type
        "txChannel": txChannel,
        "orderId": orderId,
        "orderRef": orderId,
        "txCurrency": "MYR",
        "txAmount": totalAmount.toStringAsFixed(2),
        "custName": userInfo["name"],
        "custEmail": userInfo["email"],
        "custContact": userInfo["number"],
        "productList": items
            .map((item) => {
                  "name": item["name"],
                  "qty": item["quantity"],
                  "amount": item["price"].toStringAsFixed(2),
                })
            .toList(),
      };

      // Encode to JSON and generate signature for security
      final jsonString = jsonEncode(payload); // Encode Dart Map (payload) into JSON string
      final signature = _generateSignature(jsonString);

      // Log payload and signature for debugging
      log("=== JSON Payload ===\n$jsonString");
      log("=== Signature === $signature");

      // Send HTTP POST request to AmpersandPay
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json", // Tell server the format
          "signature": signature, // Add authentication signature
        },
        body: jsonString, // Payment data as JSON
      );

      // Log response details
      log("=== Response Code: ${response.statusCode} ===");
      log("=== Response Body: ${response.body} ===");

      // ✅ Handle successful response
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);//Decode JSON response from API back into a Dart Map

        // If transaction accepted and checkout URL is available
        if (data["ret"] == 0 && data["checkoutUrl"] != null) {
          // Generate or retrieve transaction ID
          final txId = data["txId"] ??
              "TXN-${DateTime.now().millisecondsSinceEpoch}";

          // ✅ Save transaction details to Firestore
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .set({
            "txId": txId,
            "status": "pending", // Initial status before payment confirmation
            "userId": userId,
            "updatedAt": DateTime.now(),
            "createdAt": DateTime.now(),
          }, SetOptions(merge: true));

          // Return checkout info to be used in frontend redirection
          return {
            "checkoutUrl": data["checkoutUrl"],
            "txId": txId,
          };
        } else {
          // Handle unexpected API response
          return {
            "error": true,
            "message": data["msg"] ?? "Unknown API response"
          };
        }
      } else {
        // Handle non-200 HTTP response
        return {
          "error": true,
          "message": "HTTP ${response.statusCode}: ${response.body}"
        };
      }
    } catch (e) {
      // Catch and log any runtime errors (network or parsing issues)
      log("❌ processPayment Error: $e");
      return {"error": true, "message": e.toString()};
    }
  }
}
