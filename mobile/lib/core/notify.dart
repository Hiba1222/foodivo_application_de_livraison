import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

final _sb = Supabase.instance.client;

/// Fire-and-forget email notification after an order status change.
/// Silently does nothing when [Env.appUrl] is empty (local dev) or when
/// the user has no active session.
Future<void> notifyOrderStatus(String orderId, String newStatus) async {
  if (Env.appUrl.isEmpty) return;
  final token = _sb.auth.currentSession?.accessToken;
  if (token == null) return;
  try {
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('${Env.appUrl}/api/notify'));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.write(jsonEncode({'orderId': orderId, 'newStatus': newStatus}));
    final response = await request.close();
    response.drain<void>(); // discard body
    client.close();
  } catch (_) {
    // Never surface notification errors to the user
  }
}
