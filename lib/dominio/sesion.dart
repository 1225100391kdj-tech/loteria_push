
import 'dart:convert';

/// Guarda los datos necesarios para recuperar
/// la partida cuando el jugador vuelve a abrir
/// Lotería Push.
class Sesion {
  const Sesion({
    required this.sala,
    required this.nombre,
    required this.tabla,
    required this.claveJugador,
  });

  // Código de la sala.
  final String sala;

  // Nombre del jugador.
  final String nombre;

  // Las 16 cartas de su tabla.
  final List<int> tabla;

  // Clave privada del jugador.
  final String claveJugador;

  // Convertir la sesión a texto JSON.
  String aTexto() {
    return jsonEncode({
      'sala': sala,
      'nombre': nombre,
      'tabla': tabla,
      'claveJugador': claveJugador,
    });
  }

  // Recuperar una sesión desde un texto JSON.
  static Sesion? desdeTexto(String? texto) {
    if (texto == null) {
      return null;
    }

    try {
      final json = jsonDecode(texto);

      // Comprobar que los datos sean un objeto.
      if (json is! Map<String, dynamic>) {
        return null;
      }

      final tabla = json['tabla'];

      // Validar los datos del jugador.
      if (json['sala'] is! String ||
          json['nombre'] is! String ||
          json['claveJugador'] is! String) {
        return null;
      }

      // La tabla debe contener 16 números enteros.
      if (tabla is! List ||
          tabla.length != 16 ||
          tabla.any((elemento) => elemento is! int)) {
        return null;
      }

      return Sesion(
        sala: json['sala'] as String,
        nombre: json['nombre'] as String,
        tabla: tabla.cast<int>(),
        claveJugador: json['claveJugador'] as String,
      );
    } on FormatException {
      // Si el texto no es JSON válido,
      // se descarta sin cerrar la aplicación.
      return null;
    }
  }
}
