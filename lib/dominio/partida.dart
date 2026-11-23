
import 'evento.dart';
import 'lineas.dart';

// Posibles resultados al recibir un evento.
enum ResultadoAplicar {
  aplicado,
  duplicado,
  hueco,
  informativo,
}

/// Representa la partida desde el punto de vista
/// de un jugador.
///
/// Controla las cartas cantadas y detecta
/// notificaciones repetidas o cartas perdidas.
class Partida {
  Partida({
    required this.sala,
    required this.nombre,
    required this.tabla,
  });

  final String sala;
  final String nombre;
  final List<int> tabla;

  // Cartas recibidas durante la partida.
  final List<CartaCantada> _cantadas = [];

  String? ganador;
  String? patronGanador;

  bool casi = false;
  int? cartaQueFalta;

  // Obtener las cartas cantadas sin permitir
  // que se modifique la lista original.
  List<CartaCantada> get cantadas =>
      List.unmodifiable(_cantadas);

  // Número de cartas recibidas.
  int get ultima => _cantadas.length;

  // Identificadores de las cartas cantadas.
  Set<int> get idsCantados => {
        for (final carta in _cantadas)
          carta.cartaId,
      };

  // Última carta que salió.
  CartaCantada? get ultimaCarta =>
      _cantadas.isEmpty ? null : _cantadas.last;

  // Comprobar si una carta ya salió.
  bool estaMarcada(int cartaId) {
    return idsCantados.contains(cartaId);
  }

  // Identificar patrones ganadores.
  List<String> get patrones =>
      patronesCompletos(tabla, idsCantados);

  // Habilitar el botón de Lotería cuando
  // exista un patrón y no haya ganador.
  bool get puedeCantarLoteria =>
      ganador == null && patrones.isNotEmpty;

  // Aplicar una carta o notificación recibida.
  ResultadoAplicar aplicar(EventoJuego evento) {
    switch (evento) {
      case CartaCantada carta:
        // Ignorar cartas que ya fueron recibidas.
        if (carta.n <= ultima) {
          return ResultadoAplicar.duplicado;
        }

        // Detectar cartas faltantes.
        if (carta.n > ultima + 1) {
          return ResultadoAplicar.hueco;
        }

        // Guardar la carta siguiente.
        _cantadas.add(carta);

        return ResultadoAplicar.aplicado;

      case LoteriaCantada loteria:
        // Comprobar si ya se registró al ganador.
        final yaEstaba = ganador == loteria.ganador;

        ganador = loteria.ganador;
        patronGanador = loteria.patron;

        return yaEstaba
            ? ResultadoAplicar.duplicado
            : ResultadoAplicar.aplicado;

      case CasiGanas aviso:
        // Informar que falta una carta para ganar.
        casi = true;
        cartaQueFalta = aviso.cartaId;

        return ResultadoAplicar.informativo;
    }
  }

  // Aplicar varias cartas recibidas del servidor.
  //
  // Primero las ordenamos para evitar problemas
  // cuando llegan desordenadas o repetidas.
  void aplicarLote(List<CartaCantada> cartas) {
    final ordenadas = [...cartas]
      ..sort((a, b) => a.n.compareTo(b.n));

    for (final carta in ordenadas) {
      aplicar(carta);
    }
  }
}
