
import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_push/dominio/evento.dart';
import 'package:loteria_push/dominio/partida.dart';

// Crear una carta de ejemplo para las pruebas.
CartaCantada carta(int n, int id) {
  return CartaCantada(
    n: n,
    cartaId: id,
    nombre: 'Carta $id',
    pista: 'Pista de la carta $id',
  );
}

void main() {
  // Crear una partida de prueba.
  Partida nueva() => Partida(
        sala: 'ABCDE',
        nombre: 'Ana',
        tabla: List.generate(16, (i) => i + 1),
      );

  // Prueba 1.
  test('las cartas en orden se aplican', () {
    final p = nueva();

    expect(
      p.aplicar(carta(1, 10)),
      ResultadoAplicar.aplicado,
    );

    expect(
      p.aplicar(carta(2, 11)),
      ResultadoAplicar.aplicado,
    );

    expect(p.ultima, 2);
    expect(p.ultimaCarta!.cartaId, 11);
  });

  // Prueba 2.
  test('un push repetido no se aplica dos veces', () {
    final p = nueva();

    p.aplicar(carta(1, 10));

    expect(
      p.aplicar(carta(1, 10)),
      ResultadoAplicar.duplicado,
    );

    expect(p.ultima, 1);
  });

  // Prueba 3.
  test('detecta un hueco cuando falta una carta', () {
    final p = nueva();

    p.aplicar(carta(1, 10));

    expect(
      p.aplicar(carta(3, 12)),
      ResultadoAplicar.hueco,
    );

    expect(
      p.ultima,
      1,
      reason: 'No debe saltarse la carta 2',
    );
  });

  // Prueba 4.
  test('aplicarLote acepta cartas desordenadas y repetidas', () {
    final p = nueva();

    p.aplicar(carta(1, 10));

    p.aplicarLote([
      carta(4, 13),
      carta(2, 11),
      carta(3, 12),
      carta(2, 11),
      carta(1, 10),
    ]);

    expect(
      p.cantadas.map((c) => c.n),
      [1, 2, 3, 4],
    );
  });

  // Prueba 5.
  test('aplicarLote se detiene cuando falta una carta', () {
    final p = nueva();

    p.aplicarLote([
      carta(1, 10),
      carta(2, 11),
      carta(4, 13),
    ]);

    expect(p.ultima, 2);
  });

  // Prueba 6.
  test('marca solamente las cartas que han salido', () {
    final p = nueva();

    p.aplicar(carta(1, 3));
    p.aplicar(carta(2, 40));

    expect(p.estaMarcada(3), isTrue);
    expect(p.estaMarcada(5), isFalse);

    expect(
      p.tabla.where(p.estaMarcada).toList(),
      [3],
    );
  });

  // Prueba 7.
  test('habilita Lotería al completar un patrón', () {
    final p = nueva();

    for (var i = 1; i <= 3; i++) {
      p.aplicar(carta(i, i));
    }

    expect(p.puedeCantarLoteria, isFalse);

    p.aplicar(carta(4, 4));

    expect(p.puedeCantarLoteria, isTrue);
    expect(p.patrones, ['fila1']);
  });

  // Prueba 8.
  test('si hay ganador nadie más puede cantar Lotería', () {
    final p = nueva();

    for (var i = 1; i <= 4; i++) {
      p.aplicar(carta(i, i));
    }

    p.aplicar(
      const LoteriaCantada(
        n: 4,
        ganador: 'Beto',
        patron: 'fila2',
      ),
    );

    expect(p.ganador, 'Beto');
    expect(p.puedeCantarLoteria, isFalse);
  });

  // Prueba 9.
  test('un aviso de Lotería repetido es duplicado', () {
    final p = nueva();

    const aviso = LoteriaCantada(
      n: 4,
      ganador: 'Beto',
      patron: 'fila2',
    );

    expect(
      p.aplicar(aviso),
      ResultadoAplicar.aplicado,
    );

    expect(
      p.aplicar(aviso),
      ResultadoAplicar.duplicado,
    );
  });

  // Prueba 10.
  test('el aviso de casi solamente informa', () {
    final p = nueva();

    expect(
      p.aplicar(
        const CasiGanas(
          n: 3,
          cartaId: 7,
        ),
      ),
      ResultadoAplicar.informativo,
    );

    expect(p.casi, isTrue);
    expect(p.cartaQueFalta, 7);
  });
}
