/*
============================================================
File: ampersand_pay_query.dart
Author: Liew Yee Shian
Project: Flutter IPG Integration (AmpersandPay)
Description:
  This file defines the AmpersandPayQuery class, which provides
  functionality to query and poll transaction statuses from the
  AmpersandPay IPG (Internet Payment Gateway) API. It handles
  secure signature generation, periodic polling, and automatic
  status updates in Firestore.

Key Responsibilities:
  • Generate SHA-512 signatures for secure API requests.
  • Query transaction status from AmpersandPay API.
  • Poll transaction periodically until confirmed or timeout.
  • Update Firestore order document when payment is successful.

Usage Notes:
  - Ensure that `cloud_firestore`, `http`, and `crypto` dependencies
    are included in pubspec.yaml.
  - Use `pollTransaction` for automatic polling of transaction status.
  - Use `queryTransaction` for on-demand transaction status check.
============================================================
*/

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// AmpersandPayQuery handles transaction status queries and polling
/// for the AmpersandPay IPG API.
class AmpersandPayQuery {
  /// Merchant ID provided by AmpersandPay
  static const String merchantId = "91012387";

  /// Integration key for generating secure signatures
  static const String integrationKey =
      "8c72119782094d0ea1972f10d597046e934732fb86500e4dad52e068938e5b16";

  /// Staging API endpoint for transaction queries
  static const String queryUrl = "https://stg-ipg.ampersandpay.com/tx/query";

  // ==============================
  // POLL TRANSACTION STATUS
  // ==============================

  /// Periodically polls a transaction until its status is confirmed or timeout.
  ///
  /// Updates the Firestore order document automatically if payment succeeds.
  ///
  /// Parameters:
  /// - [txId]: Transaction ID to query.
  /// - [orderId]: Firestore order document ID.
  /// - [intervalSeconds]: Seconds between polling attempts (default 2).
  /// - [maxAttempts]: Maximum polling attempts before timeout (default 60).
  static Future<void> pollTransaction({
    required String txId,
    required String orderId,
    int intervalSeconds = 2,
    int maxAttempts = 60,
  }) async {
    // Delay first polling attempt to ensure transaction is recorded
    await Future.delayed(const Duration(minutes: 1));

    int attempts = 0;
    // ignore: unused_local_variable
    Timer? timer;

    timer = Timer.periodic(Duration(seconds: intervalSeconds), (t) async {
      attempts++;

      // Stop polling if max attempts reached
      if (attempts > maxAttempts) {
        t.cancel();
        log("⚠️ Max polling attempts reached for txId: $txId");
        return;
      }

      try {
        // Query transaction status from API
        final statusData = await queryTransaction(txId);

        if (statusData == null) {
          log("⚠️ No response for txId $txId, retrying...");
          return;
        }

        // 1201 = transaction not yet available
        if (statusData["ret"] == 1201) {
          log("⏳ Transaction $txId not yet available, retrying...");
          return;
        }

        final status = statusData["txStatus"]?.toString().toUpperCase() ?? "";
        log("🌐 Polling txId: $txId | Status: $status");

        // Stop polling and update Firestore if payment confirmed
        if (status == "SUCCESS" || status == "PAID") {
          t.cancel();

          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .update({
            "status": "paid",
            "updatedAt": DateTime.now(),
          });

          log("✅ Order $orderId marked as PAID.");
        }
      } catch (e) {
        log("⚠️ Polling error for txId $txId: $e");
      }
    });
  }

  // ==============================
  // QUERY TRANSACTION STATUS
  // ==============================

  /// Queries the AmpersandPay API for a single transaction's status.
  ///
  /// Parameters:
  /// - [txId]: Transaction ID to query.
  ///
  /// Returns:
  /// - `Map<String, dynamic>` containing transaction details if successful.
  /// - `null` if request fails or API returns error.
  static Future<Map<String, dynamic>?> queryTransaction(String txId) async {
    try {
      // Build JSON request body
      final body = {"merchantId": merchantId, "txId": txId};
      final jsonBody = jsonEncode(body);

      // Generate secure SHA-512 signature
      final signature =
          sha512.convert(utf8.encode(jsonBody + integrationKey)).toString();

      // Send POST request to query endpoint
      final response = await http.post(
        Uri.parse(queryUrl),
        headers: {
          "Content-Type": "application/json",
          "charset": "UTF-8",
          "signature": signature,
        },
        body: jsonBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log("✅ Query Response for $txId: $data");
        return data;
      } else {
        log("❌ HTTP Error ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      log("⚠️ Exception querying txId $txId: $e");
      return null;
    }
  }
}
