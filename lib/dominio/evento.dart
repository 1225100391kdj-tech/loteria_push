
/// Representa los eventos que recibe Lotería Push.
/// Los datos recibidos se validan antes de utilizarlos.
sealed class EventoJuego {
  const EventoJuego(this.n);

  final int n;

  // Obtener el código de sala en mayúsculas.
  static String? salaDe(Map<String, Object?> datos) {
    final sala = datos['sala'];

    if (sala is String &&
        sala.isNotEmpty &&
        sala.length <= 8) {
      return sala.toUpperCase();
    }

    return null;
  }

  // Convertir los datos recibidos en un evento.
  static EventoJuego? desdeDatos(
    Map<String, Object?> datos,
  ) {
    final tipo = datos['tipo'];

    final n = _entero(
      datos['n'],
      min: 1,
      max: 54,
    );

    if (tipo is! String || n == null) {
      return null;
    }

    switch (tipo) {
      case 'carta':
        final id = _entero(
          datos['cartaId'],
          min: 1,
          max: 54,
        );

        final nombre = _texto(datos['nombre']);

        final pista = _texto(
          datos['pista'],
          max: 200,
        );

        if (id == null ||
            nombre == null ||
            pista == null) {
          return null;
        }

        return CartaCantada(
          n: n,
          cartaId: id,
          nombre: nombre,
          pista: pista,
        );

      case 'loteria':
        final ganador = _texto(
          datos['ganador'],
          max: 20,
        );

        final patron = _texto(
          datos['patron'],
          max: 20,
        );

        if (ganador == null || patron == null) {
          return null;
        }

        return LoteriaCantada(
          n: n,
          ganador: ganador,
          patron: patron,
        );

      case 'casi':
        final id = _entero(
          datos['cartaId'],
          min: 1,
          max: 54,
        );

        if (id == null) {
          return null;
        }

        return CasiGanas(
          n: n,
          cartaId: id,
        );

      default:
        // Ignorar eventos desconocidos.
        return null;
    }
  }

  // Convertir un valor a número entero.
  static int? _entero(
    Object? valor, {
    required int min,
    required int max,
  }) {
    final numero = valor is int
        ? valor
        : int.tryParse('$valor');

    if (numero != null &&
        numero >= min &&
        numero <= max) {
      return numero;
    }

    return null;
  }

  // Validar que un texto no esté vacío
  // ni supere la longitud permitida.
  static String? _texto(
    Object? valor, {
    int max = 120,
  }) {
    if (valor is! String) {
      return null;
    }

    final texto = valor.trim();

    if (texto.isNotEmpty && texto.length <= max) {
      return texto;
    }

    return null;
  }
}

// Evento generado cuando el cantor saca una carta.
final class CartaCantada extends EventoJuego {
  const CartaCantada({
    required int n,
    required this.cartaId,
    required this.nombre,
    required this.pista,
  }) : super(n);

  final int cartaId;
  final String nombre;
  final String pista;

  // Convertir una carta recibida del servidor.
  factory CartaCantada.desdeJson(
    Map<String, dynamic> json,
  ) {
    return CartaCantada(
      n: json['n'] as int,
      cartaId: json['cartaId'] as int,
      nombre: json['nombre'] as String,
      pista: json['pista'] as String,
    );
  }
}

// Evento que anuncia al ganador de una partida.
final class LoteriaCantada extends EventoJuego {
  const LoteriaCantada({
    required int n,
    required this.ganador,
    required this.patron,
  }) : super(n);

  final String ganador;
  final String patron;
}

// Evento que avisa cuando falta una carta.
final class CasiGanas extends EventoJuego {
  const CasiGanas({
    required int n,
    required this.cartaId,
  }) : super(n);

  final int cartaId;
}
