
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';

/// Maneja los mensajes de Firebase cuando
/// la aplicación está en segundo plano.
///
/// Esta función se ejecuta de manera independiente
/// y no debe modificar directamente la interfaz
/// ni el controlador de la partida.
@pragma('vm:entry-point')
Future<void> manejadorSegundoPlano(
  RemoteMessage mensaje,
) async {
  // Inicializar Firebase en segundo plano.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // No modificamos directamente la partida aquí.
  //
  // Cuando el jugador vuelva a abrir Lotería Push,
  // el controlador consultará al servidor para
  // recuperar las cartas que no haya recibido.
}
