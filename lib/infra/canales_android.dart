
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Crea los canales de notificaciones para Android.
///
/// El servidor utiliza dos canales:
/// - cartas: cartas cantadas.
/// - momentos: avisos de ¡Casi! y ¡Lotería!
Future<void> crearCanalesAndroid() async {
  final plugin = FlutterLocalNotificationsPlugin();

  // Inicializar las notificaciones locales.
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      ),
    ),
  );

  // Obtener las funciones específicas de Android.
  final android = plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  // Canal para las cartas cantadas.
  await android?.createNotificationChannel(
    const AndroidNotificationChannel(
      'cartas',
      'Cartas cantadas',
      description:
          'Cada carta que canta el cantor',
      importance: Importance.defaultImportance,
    ),
  );

  // Canal para los momentos importantes.
  await android?.createNotificationChannel(
    const AndroidNotificationChannel(
      'momentos',
      'Momentos importantes',
      description:
          'Avisos de ¡Casi! y ¡Lotería!',
      importance: Importance.high,
    ),
  );
}
