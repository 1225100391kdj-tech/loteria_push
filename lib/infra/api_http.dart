
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dominio/api_juego.dart';
import '../dominio/evento.dart';

/// Permite comunicar Flutter con el
/// servidor Node.js mediante HTTP y JSON.
class ApiHttp implements ApiJuego {
  ApiHttp(this.base, {http.Client? cliente})
      : _c = cliente ?? http.Client();

  // Dirección del servidor.
  // Ejemplo para emulador Android:
  // http://10.0.2.2:8080
  final String base;

  final http.Client _c;

  // Construir las direcciones del servidor.
  Uri _u(String ruta) {
    return Uri.parse('$base$ruta');
  }

  // Ejecutar una petición y procesar su respuesta.
  Future<Map<String, dynamic>> _pedir(
    Future<http.Response> Function() peticion,
  ) async {
    final http.Response respuesta;

    try {
      respuesta = await peticion().timeout(
        const Duration(seconds: 8),
      );
    } on Object {
      throw const ErrorApi(
        'SIN_CONEXION',
        'No se pudo contactar al cantor',
      );
    }

    Map<String, dynamic> cuerpo;

    try {
      cuerpo = jsonDecode(
        utf8.decode(respuesta.bodyBytes),
      ) as Map<String, dynamic>;
    } on Object {
      throw ErrorApi(
        'RESPUESTA_INVALIDA',
        'Respuesta inesperada (${respuesta.statusCode})',
      );
    }

    // Comprobar si el servidor reportó un error.
    if (respuesta.statusCode >= 400) {
      throw ErrorApi(
        '${cuerpo['error'] ?? 'ERROR'}',
        '${cuerpo['mensaje'] ?? 'Error del servidor'}',
      );
    }

    return cuerpo;
  }

  // Encabezados para enviar información JSON.
  Map<String, String> get _json => {
        'content-type': 'application/json',
      };

  // Convertir las cartas recibidas desde JSON.
  List<CartaCantada> _cartas(Object? lista) {
    return [
      for (final carta
          in (lista as List<dynamic>? ?? const []))
        CartaCantada.desdeJson(
          carta as Map<String, dynamic>,
        ),
    ];
  }

  // Crear una sala nueva.
  @override
  Future<SalaCreada> crearSala() async {
    final json = await _pedir(
      () => _c.post(_u('/salas')),
    );

    return SalaCreada(
      json['id'] as String,
      json['claveCantor'] as String,
    );
  }

  // Registrar un jugador en una sala.
  @override
  Future<Union> unirse(
    String sala,
    String nombre,
    DestinoPush? destino,
  ) async {
    final json = await _pedir(
      () => _c.post(
        _u('/salas/$sala/unirse'),
        headers: _json,
        body: jsonEncode({
          'nombre': nombre,
          'destino': destino?.toJson(),
        }),
      ),
    );

    return Union(
      nombre: json['nombre'] as String,
      tabla: (json['tabla'] as List<dynamic>).cast<int>(),
      claveJugador: json['claveJugador'] as String,
      cartas: _cartas(json['cartas']),
    );
  }

  // Consultar el estado de una partida.
  @override
  Future<EstadoSala> estado(
    String sala,
    int desde,
  ) async {
    final json = await _pedir(
      () => _c.get(
        _u('/salas/$sala/estado?desde=$desde'),
      ),
    );

    return EstadoSala(
      ultima: json['ultima'] as int,
      cartas: _cartas(json['cartas']),
      ganador: json['ganador'] as String?,
      patron: json['patron'] as String?,
    );
  }

  // Cantar una carta.
  @override
  Future<CartaCantada> cantar(
    String sala,
    String claveCantor,
  ) async {
    final json = await _pedir(
      () => _c.post(
        _u('/salas/$sala/cantar'),
        headers: {
          'x-cantor-clave': claveCantor,
        },
      ),
    );

    final evento = json['evento'] as Map<String, dynamic>;

    return CartaCantada(
      n: evento['n'] as int,
      cartaId: evento['cartaId'] as int,
      nombre: evento['nombre'] as String,
      pista: evento['pista'] as String,
    );
  }

  // Reclamar una victoria de Lotería.
  @override
  Future<ResultadoReclamo> reclamar(
    String sala,
    String nombre,
    String claveJugador,
  ) async {
    final json = await _pedir(
      () => _c.post(
        _u('/salas/$sala/loteria'),
        headers: {
          ..._json,
          'x-jugador-clave': claveJugador,
        },
        body: jsonEncode({
          'nombre': nombre,
        }),
      ),
    );

    return ResultadoReclamo(
      gano: json['gano'] as bool,
      patron: json['patron'] as String?,
    );
  }

  // Actualizar el token o destino de notificaciones.
  @override
  Future<void> actualizarDestino(
    String sala,
    String nombre,
    String claveJugador,
    DestinoPush destino,
  ) async {
    await _pedir(
      () => _c.put(
        _u('/salas/$sala/destino'),
        headers: {
          ..._json,
          'x-jugador-clave': claveJugador,
        },
        body: jsonEncode({
          'nombre': nombre,
          'destino': destino.toJson(),
        }),
      ),
    );
  }
}
