
import 'package:flutter/material.dart';

import '../dominio/puerto_push.dart';
import 'pantalla_cantor.dart';
import 'vms.dart';

/// Pantalla principal de Lotería Push.
///
/// Permite ingresar a una sala como jugador
/// o abrir la pantalla para ser cantor.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({
    super.key,
    required this.vm,
    required this.crearCantor,
  });

  final JuegoVm vm;
  final CantorVm Function() crearCantor;

  @override
  State<PantallaInicio> createState() =>
      _PantallaInicioState();
}

class _PantallaInicioState
    extends State<PantallaInicio> {
  // Controladores de los campos de texto.
  final _nombre = TextEditingController();
  final _sala = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    _sala.dispose();
    super.dispose();
  }

  // Explicar al usuario para qué sirven
  // las notificaciones antes de pedir permiso.
  Future<bool> _preguntarPorAvisos() async {
    // Si ya decidió, no volver a preguntar.
    if (widget.vm.permiso !=
        PermisoPush.sinPreguntar) {
      return false;
    }

    final respuesta = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text(
          '¿Quieres que el cantor te avise?',
        ),
        content: const Text(
          'Te avisaremos cuando se cante una carta '
          'y cuando estés a UNA de ganar, '
          'aunque tengas la app cerrada.\n\n'
          'Si prefieres no recibir avisos, '
          'igual puedes jugar: la aplicación '
          'revisará las cartas cada pocos segundos '
          'mientras esté abierta.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(contexto, false);
            },
            child: const Text('Mejor no'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(contexto, true);
            },
            child: const Text('Sí, avísame'),
          ),
        ],
      ),
    );

    return respuesta ?? false;
  }

  // Registrar al jugador en la sala.
  Future<void> _unirse() async {
    final nombre = _nombre.text.trim();
    final sala = _sala.text.trim();

    // Verificar que los campos tengan datos.
    if (nombre.isEmpty || sala.isEmpty) {
      return;
    }

    // Mostrar explicación de las notificaciones.
    final pedirAvisos = await _preguntarPorAvisos();

    if (!mounted) {
      return;
    }

    // Registrar al jugador.
    await widget.vm.unirse(
      sala: sala,
      nombre: nombre,
      pedirAvisos: pedirAvisos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('🐓 Lotería Push'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'El cantor canta las cartas '
                'por notificación push.\n\n'
                '¡Llena una línea y grita Lotería!',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Nombre del jugador.
              TextField(
                controller: _nombre,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'Tu nombre',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // Código de la sala.
              TextField(
                controller: _sala,
                textCapitalization:
                    TextCapitalization.characters,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Código de sala',
                  border: OutlineInputBorder(),
                ),
              ),

              // Mostrar errores o avisos.
              if (widget.vm.mensaje != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  child: Text(
                    widget.vm.mensaje!,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Botón para ingresar a la sala.
              FilledButton(
                onPressed:
                    widget.vm.ocupado ? null : _unirse,
                child: const Text('Unirme a la sala'),
              ),

              const SizedBox(height: 24),

              // Botón para crear una sala como cantor.
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PantallaCantor(
                        vm: widget.crearCantor(),
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Soy el cantor: crear una sala',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
