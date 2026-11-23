
import 'package:firebase_messaging/firebase_messaging.dart';

import '../dominio/api_juego.dart';
import '../dominio/puerto_push.dart';

/// Adaptador de Firebase Cloud Messaging.
class PuertoFcm implements PuertoPush {
  PuertoFcm() : _fcm = FirebaseMessaging.instance;

  final FirebaseMessaging _fcm;

  // Convertir los permisos de Firebase.
  PermisoPush _mapear(AuthorizationStatus estado) {
    switch (estado) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PermisoPush.concedido;

      case AuthorizationStatus.denied:
      case AuthorizationStatus.deniedPermanently:
        return PermisoPush.denegado;

      case AuthorizationStatus.notDetermined:
        return PermisoPush.sinPreguntar;
    }
  }

  // Convertir mensajes de Firebase.
  MensajePush _aMensaje(RemoteMessage mensaje) {
    return MensajePush(
      datos: Map<String, Object?>.from(
        mensaje.data,
      ),
      titulo: mensaje.notification?.title,
      cuerpo: mensaje.notification?.body,
    );
  }

  // Consultar el permiso actual.
  @override
  Future<PermisoPush> estadoPermiso() async {
    final configuracion =
        await _fcm.getNotificationSettings();

    return _mapear(
      configuracion.authorizationStatus,
    );
  }

  // Solicitar permiso para notificaciones.
  @override
  Future<PermisoPush> pedirPermiso() async {
    final configuracion = await _fcm.requestPermission(
      alert: true,
      badge: false,
      sound: true,
    );

    return _mapear(
      configuracion.authorizationStatus,
    );
  }

  // Obtener el token del dispositivo.
  // Se conserva temporalmente porque nuestro
  // servidor todavía utiliza tokens FCM.
  @override
  Future<DestinoPush?> obtenerDestino() async {
    // ignore: deprecated_member_use
    final token = await _fcm.getToken();

    if (token == null) {
      return null;
    }

    return DestinoPush('token', token);
  }

  // Detectar cambios en el token.
  @override
  Stream<DestinoPush> get destinoCambiado {
    // ignore: deprecated_member_use
    return _fcm.onTokenRefresh.map(
      (token) => DestinoPush('token', token),
    );
  }

  // Recibir mensajes con la aplicación abierta.
  @override
  Stream<MensajePush> get enPrimerPlano {
    return FirebaseMessaging.onMessage.map(
      _aMensaje,
    );
  }

  // Detectar cuando se toca una notificación.
  @override
  Stream<MensajePush>
      get alAbrirDesdeNotificacion {
    return FirebaseMessaging.onMessageOpenedApp.map(
      _aMensaje,
    );
  }

  // Obtener el mensaje que abrió la aplicación.
  @override
  Future<MensajePush?> mensajeInicial() async {
    final mensaje = await _fcm.getInitialMessage();

    if (mensaje == null) {
      return null;
    }

    return _aMensaje(mensaje);
  }

  // Suscribirse a las notificaciones de una sala.
  @override
  Future<void> suscribirTema(String tema) async {
    await _fcm.subscribeToTopic(tema);
  }

  // Cancelar la suscripción a una sala.
  @override
  Future<void> desuscribirTema(String tema) async {
    await _fcm.unsubscribeFromTopic(tema);
  }
}
