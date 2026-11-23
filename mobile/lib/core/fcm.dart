import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage _) async {}

class FcmService {
  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_bgHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Save token now if already signed in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final token = await messaging.getToken();
      if (token != null) await _save(token);
    }

    // Re-save when token rotates
    messaging.onTokenRefresh.listen(_save);

    // Save on sign-in (handles first login after app start)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        final token = await messaging.getToken();
        if (token != null) await _save(token);
      }
    });
  }

  static Future<void> _save(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('fcm_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': 'android',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
    } catch (_) {}
  }
}
