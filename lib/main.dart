
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'dominio/controlador.dart';
import 'firebase_options.dart';
import 'infra/almacen_prefs.dart';
import 'infra/api_http.dart';
import 'infra/canales_android.dart';
import 'infra/fondo.dart';
import 'infra/puerto_fcm.dart';
import 'presentacion/vms.dart';

// Dirección del servidor Node.js.
//
// En el emulador Android, 10.0.2.2 representa
// el localhost de nuestra computadora.
//
// En un teléfono físico se debe utilizar
// la IP local de la computadora.
const String urlServidor = String.fromEnvironment(
  'SERVIDOR',
  defaultValue: 'http://10.0.2.2:8080',
);

Future<void> main() async {
  // Preparar Flutter.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase con la configuración
  // generada mediante flutterfire configure.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Registrar el manejador de segundo plano
  // antes de ejecutar la aplicación.
  FirebaseMessaging.onBackgroundMessage(
    manejadorSegundoPlano,
  );

  // Evitar que iOS muestre automáticamente
  // los avisos mientras la app está al frente.
  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
  );

  // Crear los canales de notificación de Android.
  await crearCanalesAndroid();

  // Preparar la conexión HTTP al servidor.
  final api = ApiHttp(urlServidor);

  // Preparar el almacenamiento local.
  final almacen = AlmacenPrefs(
    await SharedPreferences.getInstance(),
  );

  // Conectar servidor, Firebase y almacenamiento.
  final controlador = ControladorPartida(
    api: api,
    push: PuertoFcm(),
    almacen: almacen,
  );

  // Iniciar Lotería Push.
  runApp(
    AppLoteria(
      vm: JuegoVm(controlador),
      crearCantor: () => CantorVm(api),
    ),
  );
}
