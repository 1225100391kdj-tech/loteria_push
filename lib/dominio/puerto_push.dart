
import 'api_juego.dart';

// Posibles estados del permiso de notificaciones.
enum PermisoPush {
  sinPreguntar,
  concedido,
  denegado,
}

// Representa una notificación recibida.
// Sus datos deben validarse antes de utilizarlos.
class MensajePush {
  const MensajePush({
    required this.datos,
    this.titulo,
    this.cuerpo,
  });

  final Map<String, Object?> datos;
  final String? titulo;
  final String? cuerpo;
}

// Interfaz para comunicarse con Firebase.
// Permite probar la aplicación sin depender
// directamente del SDK de Firebase.
abstract class PuertoPush {
  // Consultar el permiso actual sin abrir diálogos.
  Future<PermisoPush> estadoPermiso();

  // Solicitar autorización para las notificaciones.
  Future<PermisoPush> pedirPermiso();

  // Obtener el token o identificador del dispositivo.
  Future<DestinoPush?> obtenerDestino();

  // Detectar cambios en el identificador del dispositivo.
  Stream<DestinoPush> get destinoCambiado;

  // Recibir mensajes cuando la aplicación está abierta.
  Stream<MensajePush> get enPrimerPlano;

  // Recibir mensajes cuando el usuario toca
  // una notificación y abre la aplicación.
  Stream<MensajePush> get alAbrirDesdeNotificacion;

  // Recuperar la notificación que abrió la aplicación
  // cuando estaba completamente cerrada.
  Future<MensajePush?> mensajeInicial();

  // Suscribirse a las notificaciones de una sala.
  Future<void> suscribirTema(String tema);

  // Dejar de recibir notificaciones de una sala.
  Future<void> desuscribirTema(String tema);
}
