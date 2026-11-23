
import 'dart:async';

import 'package:loteria_push/dominio/api_juego.dart';
import 'package:loteria_push/dominio/evento.dart';
import 'package:loteria_push/dominio/puerto_push.dart';

// Crear una carta de prueba.
CartaCantada carta(int n, int id) {
  return CartaCantada(
    n: n,
    cartaId: id,
    nombre: 'Carta $id',
    pista: 'Pista $id',
  );
}

// Simular una notificación de una carta cantada.
MensajePush mensajeCarta(
  int n,
  int id, {
  String sala = 'ABCDE',
}) {
  return MensajePush(
    datos: {
      'tipo': 'carta',
      'sala': sala,
      'n': '$n',
      'cartaId': '$id',
      'nombre': 'Carta $id',
      'pista': 'Pista $id',
    },
  );
}

// Simulación del servidor Node.js.
class ApiFalsa implements ApiJuego {
  final List<CartaCantada> cartasServidor = [];

  String? ganadorServidor;
  String? patronServidor;

  List<int> tabla = List.generate(16, (i) => i + 1);

  bool reclamoGana = false;
  Object? errorEnEstado;

  int llamadasEstado = 0;
  int? ultimoDesde;

  DestinoPush? destinoAlUnirse;

  final List<DestinoPush> destinosActualizados = [];

  @override
  Future<SalaCreada> crearSala() async {
    return const SalaCreada('ABCDE', 'clave-cantor');
  }

  @override
  Future<Union> unirse(
    String sala,
    String nombre,
    DestinoPush? destino,
  ) async {
    destinoAlUnirse = destino;

    return Union(
      nombre: nombre,
      tabla: tabla,
      claveJugador: 'k1',
      cartas: cartasServidor.toList(),
    );
  }

  @override
  Future<EstadoSala> estado(
    String sala,
    int desde,
  ) async {
    llamadasEstado++;
    ultimoDesde = desde;

    if (errorEnEstado != null) {
      throw errorEnEstado!;
    }

    return EstadoSala(
      ultima: cartasServidor.length,
      cartas: cartasServidor
          .where((c) => c.n > desde)
          .toList(),
      ganador: ganadorServidor,
      patron: patronServidor,
    );
  }

  @override
  Future<CartaCantada> cantar(
    String sala,
    String claveCantor,
  ) async {
    final nuevaCarta = carta(
      cartasServidor.length + 1,
      cartasServidor.length + 1,
    );

    cartasServidor.add(nuevaCarta);

    return nuevaCarta;
  }

  @override
  Future<ResultadoReclamo> reclamar(
    String sala,
    String nombre,
    String claveJugador,
  ) async {
    return ResultadoReclamo(
      gano: reclamoGana,
      patron: reclamoGana ? 'fila1' : null,
    );
  }

  @override
  Future<void> actualizarDestino(
    String sala,
    String nombre,
    String claveJugador,
    DestinoPush destino,
  ) async {
    destinosActualizados.add(destino);
  }
}

// Simulación de Firebase Cloud Messaging.
class PuertoPushFalso implements PuertoPush {
  PermisoPush permiso = PermisoPush.sinPreguntar;

  PermisoPush respuestaDelUsuario =
      PermisoPush.concedido;

  int vecesPidioPermiso = 0;

  DestinoPush? destino = const DestinoPush(
    'token',
    'token-del-telefono-xxxxxxxxxx',
  );

  MensajePush? inicial;

  final Set<String> temas = {};

  // Canales para simular mensajes recibidos.
  final _frente =
      StreamController<MensajePush>.broadcast();

  final _abrir =
      StreamController<MensajePush>.broadcast();

  final _destino =
      StreamController<DestinoPush>.broadcast();

  // Simular una notificación con la app abierta.
  void emitirEnPrimerPlano(MensajePush mensaje) {
    _frente.add(mensaje);
  }

  // Simular una notificación que abre la app.
  void emitirAperturaDesdeNotificacion(
    MensajePush mensaje,
  ) {
    _abrir.add(mensaje);
  }

  // Simular un cambio de token.
  void emitirNuevoDestino(DestinoPush nuevo) {
    _destino.add(nuevo);
  }

  @override
  Future<PermisoPush> estadoPermiso() async {
    return permiso;
  }

  @override
  Future<PermisoPush> pedirPermiso() async {
    vecesPidioPermiso++;
    permiso = respuestaDelUsuario;
    return permiso;
  }

  @override
  Future<DestinoPush?> obtenerDestino() async {
    return destino;
  }

  @override
  Stream<DestinoPush> get destinoCambiado =>
      _destino.stream;

  @override
  Stream<MensajePush> get enPrimerPlano =>
      _frente.stream;

  @override
  Stream<MensajePush>
      get alAbrirDesdeNotificacion => _abrir.stream;

  @override
  Future<MensajePush?> mensajeInicial() async {
    return inicial;
  }

  @override
  Future<void> suscribirTema(String tema) async {
    temas.add(tema);
  }

  @override
  Future<void> desuscribirTema(String tema) async {
    temas.remove(tema);
  }
}
