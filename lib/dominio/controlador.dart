
import 'dart:async';

import 'almacen.dart';
import 'api_juego.dart';
import 'evento.dart';
import 'partida.dart';
import 'puerto_push.dart';
import 'sesion.dart';

/// Controlador principal de Lotería Push.
///
/// Conecta la API del servidor, las notificaciones
/// y el estado de la partida.
///
/// Regla principal:
/// El push es un aviso, pero el servidor
/// contiene la información verdadera.
class ControladorPartida {
  ControladorPartida({
    required this.api,
    required this.push,
    required this.almacen,
  });

  final ApiJuego api;
  final PuertoPush push;
  final Almacen almacen;

  static const _kSesion = 'sesion';

  Partida? partida;

  PermisoPush permiso = PermisoPush.sinPreguntar;

  bool avisosActivos = false;

  String? ultimoError;

  Sesion? _sesion;

  bool _sincronizando = false;

  // Notificar los cambios a la interfaz.
  final _cambios = StreamController<void>.broadcast();

  // Suscripciones a las notificaciones.
  final List<StreamSubscription<Object?>> _subs = [];

  Stream<void> get cambios => _cambios.stream;

  // Avisar que hubo un cambio en la partida.
  void _notificar() {
    if (!_cambios.isClosed) {
      _cambios.add(null);
    }
  }

  // Consultar si las notificaciones están permitidas.
  Future<void> leerPermiso() async {
    permiso = await push.estadoPermiso();
    _notificar();
  }

  // Solicitar permiso de notificaciones.
  //
  // Esta función debe llamarse desde la pantalla
  // después de explicar al usuario para qué
  // sirven los avisos.
  Future<PermisoPush> pedirPermisoAvisos() async {
    permiso = await push.pedirPermiso();

    _notificar();

    return permiso;
  }

  // Registrar un jugador en una sala.
  Future<void> unirse({
    required String sala,
    required String nombre,
  }) async {
    // Normalizar el código de la sala.
    final id = sala.trim().toUpperCase();

    // Consultar el permiso sin mostrar diálogos.
    permiso = await push.estadoPermiso();

    // Obtener el token únicamente si hay permiso.
    final destino = permiso == PermisoPush.concedido
        ? await push.obtenerDestino()
        : null;

    // Registrar al jugador en el servidor.
    final union = await api.unirse(
      id,
      nombre,
      destino,
    );

    // Preparar los datos para recuperar la sesión.
    final sesion = Sesion(
      sala: id,
      nombre: union.nombre,
      tabla: union.tabla,
      claveJugador: union.claveJugador,
    );

    // Guardar la sesión.
    await almacen.guardarTexto(
      _kSesion,
      sesion.aTexto(),
    );

    // Iniciar la partida.
    await _empezar(sesion);

    // Recuperar las cartas que ya habían salido.
    partida!.aplicarLote(union.cartas);

    _notificar();
  }

  // Restaurar una partida cuando se abre la app.
  Future<bool> restaurar() async {
    final sesion = Sesion.desdeTexto(
      await almacen.leerTexto(_kSesion),
    );

    // Si no existe una sesión válida, no restaurar.
    if (sesion == null) {
      return false;
    }

    permiso = await push.estadoPermiso();

    // Preparar nuevamente la partida.
    await _empezar(sesion);

    // Revisar si la aplicación se abrió
    // desde una notificación.
    final inicial = await push.mensajeInicial();

    if (inicial != null) {
      await _alRecibir(inicial);
    }

    // Consultar siempre el estado real del servidor.
    await sincronizar();

    return true;
  }

  // Iniciar la partida y escuchar notificaciones.
  Future<void> _empezar(Sesion sesion) async {
    _sesion = sesion;

    partida = Partida(
      sala: sesion.sala,
      nombre: sesion.nombre,
      tabla: sesion.tabla,
    );

    avisosActivos =
        permiso == PermisoPush.concedido;

    // Suscribirse a las cartas de la sala.
    if (avisosActivos) {
      await push.suscribirTema(
        'sala_${sesion.sala}',
      );
    }

    // Cancelar suscripciones anteriores.
    for (final suscripcion in _subs) {
      await suscripcion.cancel();
    }

    _subs.clear();

    // Escuchar mensajes con la aplicación abierta.
    _subs.add(
      push.enPrimerPlano.listen(_alRecibir),
    );

    // Escuchar cuando el usuario toca
    // una notificación desde segundo plano.
    _subs.add(
      push.alAbrirDesdeNotificacion.listen(
        (mensaje) async {
          await _alRecibir(mensaje);

          // Recuperar posibles cartas perdidas.
          await sincronizar();
        },
      ),
    );

    // Escuchar cambios del token del dispositivo.
    _subs.add(
      push.destinoCambiado.listen(
        _alCambiarDestino,
      ),
    );
  }

  // Procesar una notificación recibida.
  Future<void> _alRecibir(MensajePush mensaje) async {
    final p = partida;

    if (p == null) {
      return;
    }

    // Ignorar avisos pertenecientes a otra sala.
    if (EventoJuego.salaDe(mensaje.datos) != p.sala) {
      return;
    }

    // Validar los datos recibidos.
    final evento = EventoJuego.desdeDatos(
      mensaje.datos,
    );

    // Ignorar mensajes incorrectos o desconocidos.
    if (evento == null) {
      return;
    }

    // Aplicar el evento.
    final resultado = p.aplicar(evento);

    // Si falta una carta, consultar al servidor.
    if (resultado == ResultadoAplicar.hueco) {
      await sincronizar();
    }

    _notificar();
  }

  // Recuperar las cartas que faltan desde el servidor.
  Future<void> sincronizar() async {
    final p = partida;

    // Evitar consultas duplicadas.
    if (p == null || _sincronizando) {
      return;
    }

    _sincronizando = true;

    try {
      // Solicitar solamente las cartas pendientes.
      final estado = await api.estado(
        p.sala,
        p.ultima,
      );

      // Aplicar las cartas recibidas.
      p.aplicarLote(estado.cartas);

      // Actualizar el ganador, si existe.
      if (estado.ganador != null) {
        p.ganador = estado.ganador;
        p.patronGanador = estado.patron;
      }

      // Limpiar errores anteriores.
      ultimoError = null;
    } on Object catch (error) {
      // Guardar un mensaje entendible.
      if (error is ErrorApi) {
        ultimoError = error.mensaje;
      } else {
        ultimoError = 'Sin conexión con el cantor';
      }
    } finally {
      _sincronizando = false;
      _notificar();
    }
  }

  // Actualizar el token cuando Firebase lo cambie.
  Future<void> _alCambiarDestino(
    DestinoPush destino,
  ) async {
    final sesion = _sesion;

    if (sesion == null) {
      return;
    }

    try {
      await api.actualizarDestino(
        sesion.sala,
        sesion.nombre,
        sesion.claveJugador,
        destino,
      );
    } on Object {
      // Un error de red no debe cerrar la partida.
      // Se podrá actualizar nuevamente después.
    }
  }

  // Solicitar al servidor que compruebe
  // si el jugador realmente ganó.
  Future<ResultadoReclamo> reclamarLoteria() async {
    final p = partida!;
    final sesion = _sesion!;

    final resultado = await api.reclamar(
      p.sala,
      sesion.nombre,
      sesion.claveJugador,
    );

    if (resultado.gano) {
      p.ganador = sesion.nombre;
      p.patronGanador = resultado.patron;

      _notificar();
    }

    return resultado;
  }

  // Salir de la partida.
  Future<void> salir() async {
    final p = partida;

    // Dejar de escuchar los mensajes.
    for (final suscripcion in _subs) {
      await suscripcion.cancel();
    }

    _subs.clear();

    // Cancelar la suscripción a la sala.
    if (p != null && avisosActivos) {
      await push.desuscribirTema(
        'sala_${p.sala}',
      );
    }

    // Eliminar la sesión guardada.
    await almacen.borrar(_kSesion);

    partida = null;
    _sesion = null;
    avisosActivos = false;

    _notificar();
  }

  // Liberar los recursos del controlador.
  Future<void> cerrar() async {
    for (final suscripcion in _subs) {
      await suscripcion.cancel();
    }

    _subs.clear();

    await _cambios.close();
  }
}
