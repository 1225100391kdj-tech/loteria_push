
import 'package:flutter/material.dart';

import 'vms.dart';

/// Pantalla para crear salas y cantar cartas.
class PantallaCantor extends StatefulWidget {
  const PantallaCantor({
    super.key,
    required this.vm,
  });

  final CantorVm vm;

  @override
  State<PantallaCantor> createState() =>
      _PantallaCantorState();
}

class _PantallaCantorState
    extends State<PantallaCantor> {

  @override
  void dispose() {
    // Detener el canto automático y liberar recursos.
    widget.vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final vm = widget.vm;

        return Scaffold(
          appBar: AppBar(
            title: const Text('🎙️ Cantor'),
          ),

          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // Mostrar el botón para crear una sala.
              if (vm.sala == null)
                FilledButton(
                  onPressed: vm.crear,
                  child: const Text('Crear sala'),
                )

              // Si ya existe una sala, mostrar
              // su código y las opciones del cantor.
              else ...[
                Center(
                  child: Text(
                    'Código: ${vm.sala!.id}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium,
                  ),
                ),

                const SizedBox(height: 8),

                const Center(
                  child: Text(
                    'Compártelo con tus jugadores',
                  ),
                ),

                const SizedBox(height: 12),

                // Cantar una carta manualmente.
                FilledButton(
                  onPressed: vm.cantar,
                  child: const Text(
                    'Cantar la siguiente carta',
                  ),
                ),

                // Activar o detener el canto automático.
                SwitchListTile(
                  title: const Text(
                    'Cantar automáticamente cada 6 s',
                  ),
                  subtitle: const Text(
                    'Mantén esta pantalla abierta',
                  ),
                  value: vm.automatico,
                  onChanged: (_) {
                    vm.alternarAutomatico();
                  },
                ),
              ],

              // Mostrar mensajes del servidor.
              if (vm.mensaje != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    vm.mensaje!,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),

              const Divider(),

              // Mostrar las cartas que ya se cantaron.
              for (final carta in vm.cantadas)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                  ),
                  child: Text(carta),
                ),
            ],
          ),
        );
      },
    );
  }
}
