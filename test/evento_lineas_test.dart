
import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_push/dominio/evento.dart';
import 'package:loteria_push/dominio/lineas.dart';

void main() {
  Map<String, Object?> datos(Map<String, Object?> extra) => {
        'tipo': 'carta',
        'sala': 'ABCDE',
        'n': '5',
        'cartaId': '1',
        'nombre': 'El Gallo',
        'pista': 'Madruga.',
        ...extra,
      };

  group('parsear lo que llega por push', () {
    test('carta válida con números en texto', () {
      final e = EventoJuego.desdeDatos(datos({}))!
          as CartaCantada;

      expect(
        (e.n, e.cartaId, e.nombre),
        (5, 1, 'El Gallo'),
      );
    });

    test('también acepta enteros de verdad', () {
      final e = EventoJuego.desdeDatos(
        datos({'n': 5, 'cartaId': 1}),
      );

      expect(e, isA<CartaCantada>());
    });

    test('lotería y casi', () {
      final l = EventoJuego.desdeDatos({
        'tipo': 'loteria',
        'n': '9',
        'ganador': 'Ana',
        'patron': 'fila1',
      });

      expect(l, isA<LoteriaCantada>());

      final c = EventoJuego.desdeDatos({
        'tipo': 'casi',
        'n': '7',
        'cartaId': '12',
      }) as CasiGanas;

      expect(c.cartaId, 12);
    });

    test('datos incompletos se descartan', () {
      for (final falta in [
        'n',
        'cartaId',
        'nombre',
        'pista',
        'tipo',
      ]) {
        final d = datos({})..remove(falta);

        expect(
          EventoJuego.desdeDatos(d),
          isNull,
          reason: 'sin $falta',
        );
      }
    });

    test('valores fuera de rango se descartan', () {
      for (final malo in <Map<String, Object?>>[
        {'n': '0'},
        {'n': '55'},
        {'n': 'abc'},
        {'n': null},
        {'cartaId': '0'},
        {'cartaId': '99'},
        {'nombre': ''},
        {'nombre': ' '},
        {'nombre': 'x' * 200},
        {'tipo': 'borrarTodo'},
        {'tipo': 42},
      ]) {
        expect(
          EventoJuego.desdeDatos(datos(malo)),
          isNull,
          reason: '$malo',
        );
      }
    });

    test('salaDe normaliza a mayúsculas', () {
      expect(
        EventoJuego.salaDe({'sala': 'abcde'}),
        'ABCDE',
      );

      expect(
        EventoJuego.salaDe({'sala': ''}),
        isNull,
      );

      expect(
        EventoJuego.salaDe({'sala': 'x' * 30}),
        isNull,
      );

      expect(
        EventoJuego.salaDe({}),
        isNull,
      );
    });
  });

  group('patrones ganadores', () {
    final tabla = List.generate(16, (i) => i + 1);

    List<String> comp(List<int> ids) =>
        patronesCompletos(tabla, ids.toSet());

    test('sin cartas no hay patrones', () {
      expect(comp([]), isEmpty);
    });

    test('primera fila', () {
      expect(comp([1, 2, 3, 4]), ['fila1']);
    });

    test('primera columna', () {
      expect(comp([1, 5, 9, 13]), ['columna1']);
    });

    test('primera diagonal', () {
      expect(comp([1, 6, 11, 16]), ['diagonal1']);
    });

    test('segunda diagonal', () {
      expect(comp([4, 7, 10, 13]), ['diagonal2']);
    });

    test('cuatro esquinas', () {
      expect(comp([1, 4, 13, 16]), ['esquinas']);
    });

    test('centro', () {
      expect(comp([6, 7, 10, 11]), ['centro']);
    });

    test('una carta de menos no cuenta', () {
      expect(comp([1, 2, 3]), isEmpty);
    });

    test('se ignoran cartas ajenas a la tabla', () {
      expect(
        comp([1, 2, 3, 40, 50]),
        isEmpty,
      );
    });

    test('tabla llena contiene 13 patrones', () {
      final resultado = comp(
        List.generate(16, (i) => i + 1),
      );

      expect(resultado.first, 'llena');
      expect(resultado.length, 13);
    });

    test('descripciones de patrones', () {
      expect(
        describirPatron('fila2'),
        'la fila 2',
      );

      expect(
        describirPatron('columna4'),
        'la columna 4',
      );

      expect(
        describirPatron('diagonal2'),
        'una diagonal',
      );

      expect(
        describirPatron('esquinas'),
        'las cuatro esquinas',
      );

      expect(
        describirPatron('llena'),
        'la tabla llena',
      );
    });
  });
}
