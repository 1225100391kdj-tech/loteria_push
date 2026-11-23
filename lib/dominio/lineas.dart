
/// Patrones ganadores de Lotería Push.
/// Cada número representa una posición
/// de una tabla de 4 filas por 4 columnas.
///
///  0   1   2   3
///  4   5   6   7
///  8   9  10  11
/// 12  13  14  15

const Map<String, List<int>> patrones = {
  // Tabla completa.
  'llena': [
    0, 1, 2, 3,
    4, 5, 6, 7,
    8, 9, 10, 11,
    12, 13, 14, 15,
  ],

  // Filas.
  'fila1': [0, 1, 2, 3],
  'fila2': [4, 5, 6, 7],
  'fila3': [8, 9, 10, 11],
  'fila4': [12, 13, 14, 15],

  // Columnas.
  'columna1': [0, 4, 8, 12],
  'columna2': [1, 5, 9, 13],
  'columna3': [2, 6, 10, 14],
  'columna4': [3, 7, 11, 15],

  // Diagonales.
  'diagonal1': [0, 5, 10, 15],
  'diagonal2': [3, 6, 9, 12],

  // Esquinas.
  'esquinas': [0, 3, 12, 15],

  // Centro.
  'centro': [5, 6, 9, 10],
};

/// Identificar los patrones completos.
///
/// tabla: las 16 cartas del jugador.
/// cantadas: los identificadores de las
/// cartas que ya salieron.
List<String> patronesCompletos(
  List<int> tabla,
  Set<int> cantadas,
) {
  return [
    for (final patron in patrones.entries)
      if (patron.value.every(
        (posicion) => cantadas.contains(tabla[posicion]),
      ))
        patron.key,
  ];
}

/// Convertir el código de un patrón
/// en una descripción entendible.
String describirPatron(String nombre) {
  if (nombre == 'llena') {
    return 'la tabla llena';
  }

  if (nombre == 'esquinas') {
    return 'las cuatro esquinas';
  }

  if (nombre == 'centro') {
    return 'el centro';
  }

  if (nombre.startsWith('diagonal')) {
    return 'una diagonal';
  }

  final resultado = RegExp(
    r'^(fila|columna)(\d)$',
  ).firstMatch(nombre);

  if (resultado == null) {
    return nombre;
  }

  return 'la ${resultado.group(1)} ${resultado.group(2)}';
}
