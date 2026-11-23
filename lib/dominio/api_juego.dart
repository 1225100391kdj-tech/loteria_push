
import 'evento.dart';

// Destino para recibir notificaciones push.
class DestinoPush {
  const DestinoPush(this.tipo, this.valor);

  // Puede ser 'token' o 'fid'.
  final String tipo;
  final String valor;

  Map<String, String> toJson() => {
        'tipo': tipo,
        'valor': valor,
      };
}

// Información de una sala recién creada.
class SalaCreada {
  const SalaCreada(this.id, this.claveCantor);

  final String id;
  final String claveCantor;
}

// Información que recibe un jugador al unirse.
class Union {
  const Union({
    required this.nombre,
    required this.tabla,
    required this.claveJugador,
    required this.cartas,
  });

  final String nombre;
  final List<int> tabla;
  final String claveJugador;
  final List<CartaCantada> cartas;
}

// Estado actual de una sala.
class EstadoSala {
  const EstadoSala({
    required this.ultima,
    required this.cartas,
    this.ganador,
    this.patron,
  });

  final int ultima;
  final List<CartaCantada> cartas;
  final String? ganador;
  final String? patron;
}

// Resultado de una reclamación de Lotería.
class ResultadoReclamo {
  const ResultadoReclamo({
    required this.gano,
    this.patron,
  });

  final bool gano;
  final String? patron;
}

// Errores recibidos del servidor.
class ErrorApi implements Exception {
  const ErrorApi(this.codigo, this.mensaje);

  final String codigo;
  final String mensaje;

  @override
  String toString() {
    return 'ErrorApi($codigo): $mensaje';
  }
}

// Contrato para comunicarse con el servidor.
abstract class ApiJuego {
  // Crear una sala nueva.
  Future<SalaCreada> crearSala();

  // Registrar un jugador.
  Future<Union> unirse(
    String sala,
    String nombre,
    DestinoPush? destino,
  );

  // Consultar las cartas cantadas.
  Future<EstadoSala> estado(
    String sala,
    int desde,
  );

  // Cantar una carta.
  Future<CartaCantada> cantar(
    String sala,
    String claveCantor,
  );

  // Reclamar una victoria.
  Future<ResultadoReclamo> reclamar(
    String sala,
    String nombre,
    String claveJugador,
  );

  // Actualizar el destino de notificaciones.
  Future<void> actualizarDestino(
    String sala,
    String nombre,
    String claveJugador,
    DestinoPush destino,
  );
}
