
import 'package:flutter/material.dart';

import 'presentacion/pantalla_inicio.dart';
import 'presentacion/pantalla_juego.dart';
import 'presentacion/vms.dart';

/// Aplicación principal de Lotería Push.
class AppLoteria extends StatefulWidget {
  const AppLoteria({
    super.key,
    required this.vm,
    required this.crearCantor,
  });

  final JuegoVm vm;
  final CantorVm Function() crearCantor;

  @override
  State<AppLoteria> createState() =>
      _AppLoteriaState();
}

class _AppLoteriaState extends State<AppLoteria>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();

    // Observar los cambios de estado de la app.
    WidgetsBinding.instance.addObserver(this);

    // Comprobar si existe una partida guardada.
    widget.vm.iniciar();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    // Cuando el jugador regresa a la aplicación,
    // consultar al servidor por cartas pendientes.
    if (state == AppLifecycleState.resumed) {
      widget.vm.alVolverALaApp();
    }
  }

  @override
  void dispose() {
    // Dejar de observar los cambios de la app.
    WidgetsBinding.instance.removeObserver(this);

    // Liberar recursos del ViewModel.
    widget.vm.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lotería Push',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),

      // Cambiar automáticamente entre
      // la pantalla de inicio y la de juego.
      home: ListenableBuilder(
        listenable: widget.vm,
        builder: (context, _) {
          // Si no hay partida, mostrar el inicio.
          if (widget.vm.partida == null) {
            return PantallaInicio(
              vm: widget.vm,
              crearCantor: widget.crearCantor,
            );
          }

          // Si hay una partida, mostrar las cartas.
          return PantallaJuego(
            vm: widget.vm,
          );
        },
      ),
    );
  }
}
