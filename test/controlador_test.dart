
import 'package:flutter_test/flutter_test.dart';
import 'package:loteria_push/dominio/almacen.dart';
import 'package:loteria_push/dominio/api_juego.dart';
import 'package:loteria_push/dominio/controlador.dart';
import 'package:loteria_push/dominio/puerto_push.dart';

import 'falsos.dart';

void main() {
  late ApiFalsa api;
  late PuertoPushFalso push;
  late AlmacenMemoria almacen;
  late ControladorPartida c;

  setUp(() {
    api = ApiFalsa();
    push = PuertoPushFalso();
    almacen = AlmacenMemoria();

    c = ControladorPartida(
      api: api,
      push: push,
      almacen: almacen,
    );
  });

  tearDown(() => c.cerrar());

  // PRUEBAS DE PERMISOS Y REGISTRO
  group('permiso y registro', () {
    test('unirse con permiso registra el destino y el tema',
        () async {
      push.permiso = PermisoPush.concedido;

      await c.unirse(
        sala: 'abcde',
        nombre: 'Ana',
      );

      expect(api.destinoAlUnirse?.tipo, 'token');
      expect(push.temas, {'sala_ABCDE'});
      expect(c.avisosActivos, isTrue);
    });

    test('unirse sin permiso no solicita autorización',
        () async {
      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );

      expect(push.vecesPidioPermiso, 0);
      expect(api.destinoAlUnirse, isNull);
      expect(push.temas, isEmpty);
      expect(c.avisosActivos, isFalse);
      expect(c.partida, isNotNull);
    });

    test('pedir permiso actualiza el estado', () async {
      expect(
        await c.pedirPermisoAvisos(),
        PermisoPush.concedido,
      );

      expect(push.vecesPidioPermiso, 1);
    });

    test('si rechaza el permiso, juega sin avisos',
        () async {
      push.respuestaDelUsuario =
          PermisoPush.denegado;

      await c.pedirPermisoAvisos();

      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );

      expect(c.avisosActivos, isFalse);
      expect(api.destinoAlUnirse, isNull);
    });
  });

  // PRUEBAS DE NOTIFICACIONES
  group('llegada de pushes', () {
    setUp(() async {
      push.permiso = PermisoPush.concedido;

      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );
    });

    test('los mensajes en orden se aplican', () async {
      push.emitirEnPrimerPlano(mensajeCarta(1, 10));
      push.emitirEnPrimerPlano(mensajeCarta(2, 11));

      await pumpEventQueue();

      expect(c.partida!.ultima, 2);
      expect(api.llamadasEstado, 0);
    });

    test('un mensaje duplicado se ignora', () async {
      push.emitirEnPrimerPlano(mensajeCarta(1, 10));
      push.emitirEnPrimerPlano(mensajeCarta(1, 10));

      await pumpEventQueue();

      expect(c.partida!.ultima, 1);
    });

    test('un hueco provoca una sincronización', () async {
      api.cartasServidor.addAll([
        carta(1, 10),
        carta(2, 11),
        carta(3, 12),
      ]);

      // Se recibe la carta 3 sin haber visto
      // las cartas 1 y 2.
      push.emitirEnPrimerPlano(mensajeCarta(3, 12));

      await pumpEventQueue();

      expect(api.llamadasEstado, 1);
      expect(api.ultimoDesde, 0);
      expect(c.partida!.ultima, 3);
    });

    test('ignora mensajes de otra sala o incorrectos',
        () async {
      push.emitirEnPrimerPlano(
        mensajeCarta(1, 10, sala: 'OTRA1'),
      );

      push.emitirEnPrimerPlano(
        const MensajePush(
          datos: {'tipo': 'borrarTodo'},
        ),
      );

      push.emitirEnPrimerPlano(
        const MensajePush(datos: {}),
      );

      await pumpEventQueue();

      expect(c.partida!.ultima, 0);
    });

    test('un aviso de Lotería registra al ganador',
        () async {
      push.emitirEnPrimerPlano(
        const MensajePush(
          datos: {
            'tipo': 'loteria',
            'sala': 'ABCDE',
            'n': '9',
            'ganador': 'Beto',
            'patron': 'fila1',
          },
        ),
      );

      await pumpEventQueue();

      expect(c.partida!.ganador, 'Beto');
    });

    test('al tocar una notificación se sincroniza',
        () async {
      api.cartasServidor.addAll([
        carta(1, 10),
        carta(2, 11),
      ]);

      push.emitirAperturaDesdeNotificacion(
        mensajeCarta(1, 10),
      );

      await pumpEventQueue();

      expect(api.llamadasEstado, 1);
      expect(c.partida!.ultima, 2);
    });

    test('un cambio de token se manda al servidor',
        () async {
      push.emitirNuevoDestino(
        const DestinoPush(
          'token',
          'token-nuevo-xxxxxxxxxxxxxxxx',
        ),
      );

      await pumpEventQueue();

      expect(
        api.destinosActualizados.single.valor,
        'token-nuevo-xxxxxxxxxxxxxxxx',
      );
    });
  });

  // PRUEBAS DE SINCRONIZACIÓN
  group('al ponerse al día', () {
    test('un jugador nuevo recibe las cartas anteriores',
        () async {
      api.cartasServidor.addAll([
        carta(1, 10),
        carta(2, 11),
      ]);

      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );

      expect(c.partida!.ultima, 2);
    });

    test('sincronizar solicita solo las cartas faltantes',
        () async {
      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );

      api.cartasServidor.addAll([
        carta(1, 10),
        carta(2, 11),
      ]);

      await c.sincronizar();

      api.cartasServidor.add(carta(3, 12));

      await c.sincronizar();

      expect(api.ultimoDesde, 2);
      expect(c.partida!.ultima, 3);
    });

    test('sincronizar recupera también al ganador',
        () async {
      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );

      api.ganadorServidor = 'Beto';
      api.patronServidor = 'columna2';

      await c.sincronizar();

      expect(c.partida!.ganador, 'Beto');
    });

    test('si falla la conexión, guarda el error',
        () async {
      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );

      api.errorEnEstado = const ErrorApi(
        'SIN_CONEXION',
        'No se pudo contactar al cantor',
      );

      await c.sincronizar();

      expect(
        c.ultimoError,
        'No se pudo contactar al cantor',
      );

      api.errorEnEstado = null;

      await c.sincronizar();

      expect(c.ultimoError, isNull);
    });

    test('dos sincronizaciones realizan una consulta',
        () async {
      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );

      final a = c.sincronizar();
      final b = c.sincronizar();

      await Future.wait([a, b]);

      expect(api.llamadasEstado, 1);
    });
  });

  // PRUEBAS DE RESTAURACIÓN
  group('abrir la aplicación desde cerrada', () {
    test('sin sesión guardada no restaura', () async {
      expect(await c.restaurar(), isFalse);
    });

    test('recupera la partida y las cartas pendientes',
        () async {
      push.permiso = PermisoPush.concedido;

      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );

      await c.cerrar();

      // Se cantaron tres cartas mientras
      // la aplicación estaba cerrada.
      api.cartasServidor.addAll([
        carta(1, 10),
        carta(2, 11),
        carta(3, 12),
      ]);

      push.inicial = mensajeCarta(3, 12);

      final nuevo = ControladorPartida(
        api: api,
        push: push,
        almacen: almacen,
      );

      expect(await nuevo.restaurar(), isTrue);
      expect(nuevo.partida!.nombre, 'Ana');
      expect(nuevo.partida!.ultima, 3);
      expect(nuevo.avisosActivos, isTrue);

      await nuevo.cerrar();
    });

    test('una sesión dañada se ignora', () async {
      await almacen.guardarTexto(
        'sesion',
        '{"sala": 5}',
      );

      expect(await c.restaurar(), isFalse);
    });
  });

  // PRUEBAS DE LOTERÍA
  group('cantar Lotería', () {
    setUp(() async {
      await c.unirse(
        sala: 'ABCDE',
        nombre: 'Ana',
      );
    });

    test('una falsa alarma no registra ganador',
        () async {
      final resultado = await c.reclamarLoteria();

      expect(resultado.gano, isFalse);
      expect(c.partida!.ganador, isNull);
    });

    test('una victoria confirmada registra al ganador',
        () async {
      api.reclamoGana = true;

      await c.reclamarLoteria();

      expect(c.partida!.ganador, 'Ana');
      expect(c.partida!.patronGanador, 'fila1');
    });
  });

  // PRUEBA DE SALIDA
  test('salir elimina la sesión y las suscripciones',
      () async {
    push.permiso = PermisoPush.concedido;

    await c.unirse(
      sala: 'ABCDE',
      nombre: 'Ana',
    );

    await c.salir();

    expect(push.temas, isEmpty);
    expect(c.partida, isNull);

    expect(
      await almacen.leerTexto('sesion'),
      isNull,
    );

    push.emitirEnPrimerPlano(mensajeCarta(1, 10));

    await pumpEventQueue();

    expect(c.partida, isNull);
  });
}
