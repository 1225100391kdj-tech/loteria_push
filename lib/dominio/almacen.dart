
/// Define las operaciones para guardar y recuperar
/// información de una partida de Lotería Push.
abstract class Almacen {
  // Leer información guardada.
  Future<String?> leerTexto(String clave);

  // Guardar información.
  Future<void> guardarTexto(
    String clave,
    String valor,
  );

  // Eliminar información guardada.
  Future<void> borrar(String clave);
}

/// Almacenamiento temporal en memoria.
/// Se utiliza durante las pruebas automatizadas.
class AlmacenMemoria implements Almacen {
  final Map<String, String> _datos = {};

  @override
  Future<String?> leerTexto(String clave) async {
    return _datos[clave];
  }

  @override
  Future<void> guardarTexto(
    String clave,
    String valor,
  ) async {
    _datos[clave] = valor;
  }

  @override
  Future<void> borrar(String clave) async {
    _datos.remove(clave);
  }
}
