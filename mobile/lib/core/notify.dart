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

/// Sends an invoice email to the authenticated client for a delivered order.
/// Throws on network or server errors (caller should show a snackbar).
Future<void> emailInvoice(String orderId) async {
  if (Env.appUrl.isEmpty) throw Exception('App URL not configured');
  final token = _sb.auth.currentSession?.accessToken;
  if (token == null) throw Exception('Not authenticated');
  final client = HttpClient();
  final request = await client.postUrl(Uri.parse('${Env.appUrl}/api/invoice/$orderId'));
  request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  request.write('{}');
  final response = await request.close();
  final body = await response.transform(const Utf8Decoder()).join();
  client.close();
  if (response.statusCode != 200) throw Exception(body);
}

/// Sends a report email to the authenticated user (driver or restaurant owner).
/// [type] must be 'driver' or 'restaurant'. [period] is '7', '30', '90', or 'all'.
/// Throws on network or server errors (caller should show a snackbar).
Future<void> emailReport({required String type, required String period}) async {
  if (Env.appUrl.isEmpty) throw Exception('App URL not configured');
  final token = _sb.auth.currentSession?.accessToken;
  if (token == null) throw Exception('Not authenticated');
  final client = HttpClient();
  final request = await client.postUrl(Uri.parse('${Env.appUrl}/api/report'));
  request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  request.write(jsonEncode({'type': type, 'period': period}));
  final response = await request.close();
  final body = await response.transform(const Utf8Decoder()).join();
  client.close();
  if (response.statusCode != 200) throw Exception(body);
}
