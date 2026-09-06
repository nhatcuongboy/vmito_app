import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vmito_app/core/notifications/push_registration_manager.dart';
import 'package:vmito_app/firebase_options.dart';

Future<void> initializeFirebaseForPush() async {
  if (!supportsNativePushNotifications) return;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

/// Notification payloads are displayed by the OS in background/terminated
/// states. This handler is for the accompanying data payload and must remain a
/// top-level entry point so release tree-shaking cannot remove it.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
