// -----------------------------------------------------------------------------
//  AmpersandPayQuery SDK Utility
//  -----------------------------------------------------------------------------
//  Description:
//  This module provides functionality to query and poll transaction statuses
//  from the AmpersandPay API. It includes secure signature generation, periodic
//  status polling, and Firestore integration for automatic status updates.
// -----------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides methods to query and monitor payment transaction statuses
/// through the AmpersandPay API.
class AmpersandPayQuery {
  /// Merchant ID issued by AmpersandPay for authentication.
  static const String merchantId = "91012387";

  /// Integration key used to generate request signatures.
  static const String integrationKey =
      "8c72119782094d0ea1972f10d597046e934732fb86500e4dad52e068938e5b16";

  /// Endpoint for querying transaction statuses on the AmpersandPay staging environment.
  static const String queryUrl = "https://stg-ipg.ampersandpay.com/tx/query";

  // ---------------------------------------------------------------------------
  //  pollTransaction
  // ---------------------------------------------------------------------------
  /// Periodically polls the AmpersandPay API to retrieve the status of a given transaction.
  ///
  /// Once a transaction is marked as **SUCCESS** or **PAID**, the polling
  /// process automatically stops and the corresponding order document in
  /// Firestore is updated.
  ///
  /// **Parameters:**
  /// - [txId]: The transaction ID to be queried.
  /// - [orderId]: The Firestore document ID of the order to update.
  /// - [intervalSeconds]: Interval in seconds between polling attempts (default: 2).
  /// - [maxAttempts]: Maximum number of polling attempts before timeout (default: 60).
  ///
  /// **Behavior:**
  /// - Delays the first request by one minute to prevent premature querying.
  /// - Repeats queries at fixed intervals until a final status is received
  ///   or the maximum attempts limit is reached.
  /// - Updates Firestore automatically when payment is confirmed.
  static Future<void> pollTransaction({
    required String txId,
    required String orderId,
    int intervalSeconds = 2,
    int maxAttempts = 60,
  }) async {
    // Delay initial polling to ensure the transaction is recorded on Ampersand’s server.
    await Future.delayed(const Duration(minutes: 1));

    int attempts = 0;
    // ignore: unused_local_variable
    Timer? timer;

    timer = Timer.periodic(Duration(seconds: intervalSeconds), (t) async {
      attempts++;

      // Stop polling after reaching maximum attempts.
      if (attempts > maxAttempts) {
        t.cancel();
        log("⚠️ Max polling attempts reached for txId: $txId");
        return;
      }

      try {
        final statusData = await queryTransaction(txId);

        // Retry if no valid response is returned.
        if (statusData == null) {
          log("⚠️ No response from Ampersand, retrying...");
          return;
        }

        // 1201 indicates that the transaction record is not yet available.
        if (statusData["ret"] == 1201) {
          log("⏳ Transaction $txId not yet available, retrying...");
          return;
        }

        final status = statusData["txStatus"]?.toString().toUpperCase() ?? "";
        log("🌐 Polling txId: $txId | Status: $status");

        // Stop polling when payment is confirmed and update Firestore.
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
        log("⚠️ Polling error: $e");
      }
    });
  }

  // ---------------------------------------------------------------------------
  //  queryTransaction
  // ---------------------------------------------------------------------------
  /// Queries the AmpersandPay API for the current status of a specific transaction.
  ///
  /// **Parameters:**
  /// - [txId]: The transaction ID to be queried.
  ///
  /// **Returns:**
  /// - A `Map<String, dynamic>` containing transaction details if successful.
  /// - `null` if the request fails or response is invalid.
  ///
  /// **Behavior:**
  /// - Constructs a JSON payload containing the merchant ID and transaction ID.
  /// - Generates a secure SHA-512 signature using the integration key.
  /// - Sends a POST request to the AmpersandPay query endpoint.
  /// - Logs and returns the API response for further processing.
  static Future<Map<String, dynamic>?> queryTransaction(String txId) async {
    try {
      final body = {"merchantId": merchantId, "txId": txId};
      final jsonBody = jsonEncode(body);

      // Generate request signature (SHA-512 hash of JSON body + integration key).
      final signature =
          sha512.convert(utf8.encode(jsonBody + integrationKey)).toString();

      // Execute HTTP POST request to query transaction status.
      final response = await http.post(
        Uri.parse(queryUrl),
        headers: {
          "Content-Type": "application/json",
          "charset": "UTF-8",
          "signature": signature,
        },
        body: jsonBody,
      );

      // Parse and return valid response.
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log("✅ Query Response: $data");
        return data;
      } else {
        log("❌ HTTP Error ${response.statusCode}: ${response.body}");
        return null;
      }
    } catch (e) {
      log("⚠️ Exception while querying transaction: $e");
      return null;
    }
  }
}
