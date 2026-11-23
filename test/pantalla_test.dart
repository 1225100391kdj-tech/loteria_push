
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loteria_push/dominio/almacen.dart';
import 'package:loteria_push/dominio/controlador.dart';
import 'package:loteria_push/presentacion/pantalla_juego.dart';
import 'package:loteria_push/presentacion/vms.dart';

import 'falsos.dart';

void main() {
  late ApiFalsa api;
  late PuertoPushFalso push;
  late ControladorPartida controlador;
  late JuegoVm vm;

  setUp(() {
    api = ApiFalsa();
    push = PuertoPushFalso();

    controlador = ControladorPartida(
      api: api,
      push: push,
      almacen: AlmacenMemoria(),
    );

    vm = JuegoVm(controlador);
  });

  // Abrir la pantalla con un jugador registrado.
  Future<void> abrir(WidgetTester tester) async {
    await tester.runAsync(
      () => controlador.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaJuego(vm: vm),
      ),
    );
  }

  // Obtener el botón de Lotería.
  FilledButton boton(WidgetTester tester) {
    return tester.widget<FilledButton>(
      find.widgetWithText(
        FilledButton,
        '¡LOTERÍA!',
      ),
    );
  }

  // PRUEBA 1
  testWidgets(
    'Muestra la sala y las cartas del jugador',
    (tester) async {
      await abrir(tester);

      // Comprobar el código de la sala.
      expect(
        find.text('Sala ABCDE'),
        findsOneWidget,
      );

      // Comprobar que todavía no hay cartas cantadas.
      expect(
        find.text('Esperando la primera carta...'),
        findsOneWidget,
      );

      // Mostrar aviso cuando no hay notificaciones.
      expect(
        find.textContaining('Sin avisos'),
        findsOneWidget,
      );

      // Comprobar la primera carta de la tabla.
      expect(
        find.text('El Gallo'),
        findsOneWidget,
      );
    },
  );

  // PRUEBA 2
  testWidgets(
    'El botón Lotería se activa al completar un patrón',
    (tester) async {
      await abrir(tester);

      // Desplazarse hasta el botón Lotería.
      await tester.scrollUntilVisible(
        find.text('¡LOTERÍA!'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      // Al comenzar, el botón está deshabilitado.
      expect(
        boton(tester).onPressed,
        isNull,
      );

      // Simular cuatro cartas cantadas.
      api.cartasServidor.addAll([
        carta(1, 1),
        carta(2, 2),
        carta(3, 3),
        carta(4, 4),
      ]);

      // Recuperar las cartas desde el servidor.
      await tester.runAsync(
        controlador.sincronizar,
      );

      await tester.pump();

      // Verificar que completó un patrón.
      expect(
        controlador.partida!.puedeCantarLoteria,
        isTrue,
      );

      // Comprobar que el botón se activó.
      expect(
        boton(tester).onPressed,
        isNotNull,
      );

      // Desplazarse hasta la última carta cantada.
      await tester.scrollUntilVisible(
        find.textContaining('#4'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      // Comprobar que aparece la última carta.
      expect(
        find.textContaining('#4'),
        findsOneWidget,
      );
    },
  );

  // PRUEBA 3
  testWidgets(
    'Muestra al ganador y desactiva el botón Lotería',
    (tester) async {
      await abrir(tester);

      // Simular cuatro cartas cantadas.
      api.cartasServidor.addAll([
        carta(1, 1),
        carta(2, 2),
        carta(3, 3),
        carta(4, 4),
      ]);

      // Simular que otro jugador ganó.
      api.ganadorServidor = 'Beto';
      api.patronServidor = 'fila3';

      // Actualizar el estado de la partida.
      await tester.runAsync(
        controlador.sincronizar,
      );

      await tester.pump();

      // Comprobar que el controlador recibió al ganador.
      expect(
        controlador.partida!.ganador,
        'Beto',
      );

      // Comprobar que se guardó el patrón ganador.
      expect(
        controlador.partida!.patronGanador,
        'fila3',
      );

      // Desplazarse hasta el mensaje del ganador.
      await tester.scrollUntilVisible(
        find.textContaining('Beto ganó con'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      // Comprobar que aparece el ganador.
      expect(
        find.textContaining('Beto ganó con'),
        findsOneWidget,
      );

      // Comprobar que el botón Lotería está desactivado.
      expect(
        boton(tester).onPressed,
        isNull,
      );
    },
  );
}
