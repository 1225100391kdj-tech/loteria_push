
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../dominio/api_juego.dart';
import '../dominio/controlador.dart';
import '../dominio/partida.dart';
import '../dominio/puerto_push.dart';

// ViewModel para la pantalla del jugador.
class JuegoVm extends ChangeNotifier {
  JuegoVm(this.controlador) {
    _sub = controlador.cambios.listen(
      (_) => notifyListeners(),
    );
  }

  final ControladorPartida controlador;

  late final StreamSubscription<void> _sub;

  Timer? _consulta;

  String? mensaje;
  bool ocupado = false;

  Partida? get partida => controlador.partida;

  bool get avisosActivos =>
      controlador.avisosActivos;

  PermisoPush get permiso =>
      controlador.permiso;

  // Recuperar una partida cuando se abre la app.
  Future<void> iniciar() async {
    await controlador.leerPermiso();

    if (await controlador.restaurar()) {
      _vigilar();
    }

    notifyListeners();
  }

  // Si no hay notificaciones push,
  // consultar al servidor cada 5 segundos.
  void _vigilar() {
    _consulta?.cancel();

    if (controlador.avisosActivos) {
      return;
    }

    _consulta = Timer.periodic(
      const Duration(seconds: 5),
      (_) => controlador.sincronizar(),
    );
  }

  // Registrar un jugador en una sala.
  Future<void> unirse({
    required String sala,
    required String nombre,
    required bool pedirAvisos,
  }) async {
    ocupado = true;
    mensaje = null;

    notifyListeners();

    try {
      if (pedirAvisos) {
        await controlador.pedirPermisoAvisos();
      }

      await controlador.unirse(
        sala: sala,
        nombre: nombre,
      );

      _vigilar();
    } on ErrorApi catch (error) {
      mensaje = error.mensaje;
    } finally {
      ocupado = false;
      notifyListeners();
    }
  }

  // Sincronizar al regresar a la aplicación.
  Future<void> alVolverALaApp() {
    return controlador.sincronizar();
  }

  // Reclamar una victoria.
  Future<void> cantarLoteria() async {
    try {
      final resultado =
          await controlador.reclamarLoteria();

      mensaje = resultado.gano
          ? '¡Ganaste! 🎉'
          : 'Todavía no tienes Lotería... ¡paciencia!';
    } on ErrorApi catch (error) {
      mensaje = error.mensaje;
    }

    notifyListeners();
  }

  // Salir de la partida.
  Future<void> salir() async {
    _consulta?.cancel();

    await controlador.salir();
  }

  @override
  void dispose() {
    _consulta?.cancel();
    _sub.cancel();

    super.dispose();
  }
}

// ViewModel para la pantalla del cantor.
class CantorVm extends ChangeNotifier {
  CantorVm(this.api);

  final ApiJuego api;

  SalaCreada? sala;

  final List<String> cantadas = [];

  String? mensaje;

  Timer? _auto;

  bool get automatico => _auto != null;

  // Crear una sala nueva.
  Future<void> crear() async {
    try {
      sala = await api.crearSala();
      mensaje = null;
    } on ErrorApi catch (error) {
      mensaje = error.mensaje;
    }

    notifyListeners();
  }

  // Cantar la siguiente carta.
  Future<void> cantar() async {
    final salaActual = sala;

    if (salaActual == null) {
      return;
    }

    try {
      final carta = await api.cantar(
        salaActual.id,
        salaActual.claveCantor,
      );

      cantadas.insert(
        0,
        '${carta.n}. ${carta.nombre}',
      );

      mensaje = null;
    } on ErrorApi catch (error) {
      mensaje = error.mensaje;

      if (error.codigo == 'SALA_TERMINADA' ||
          error.codigo == 'SIN_CARTAS') {
        detenerAutomatico();
      }
    }

    notifyListeners();
  }

  // Activar o detener el canto automático.
  void alternarAutomatico() {
    if (automatico) {
      detenerAutomatico();
    } else {
      _auto = Timer.periodic(
        const Duration(seconds: 6),
        (_) => cantar(),
      );
    }

    notifyListeners();
  }

  // Detener el canto automático.
  void detenerAutomatico() {
    _auto?.cancel();
    _auto = null;
  }

  @override
  void dispose() {
    detenerAutomatico();

    super.dispose();
  }
}
