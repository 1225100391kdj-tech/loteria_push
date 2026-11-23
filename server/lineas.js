
'use strict';

// Una tabla de lotería tiene 4 filas y 4 columnas.
//
// Posiciones:
//  0   1   2   3
//  4   5   6   7
//  8   9  10  11
// 12  13  14  15

// Definir todos los patrones ganadores.
const PATRONES = [
  // Tabla completa.
  [
    'llena',
    Array.from({ length: 16 }, (_, i) => i)
  ],

  // Cuatro filas.
  ...[0, 4, 8, 12].map((inicio, i) => [
    `fila${i + 1}`,
    [inicio, inicio + 1, inicio + 2, inicio + 3]
  ]),

  // Cuatro columnas.
  ...[0, 1, 2, 3].map((inicio, i) => [
    `columna${i + 1}`,
    [inicio, inicio + 4, inicio + 8, inicio + 12]
  ]),

  // Primera diagonal.
  [
    'diagonal1',
    [0, 5, 10, 15]
  ],

  // Segunda diagonal.
  [
    'diagonal2',
    [3, 6, 9, 12]
  ],

  // Cuatro esquinas.
  [
    'esquinas',
    [0, 3, 12, 15]
  ],

  // Cuatro cartas del centro.
  [
    'centro',
    [5, 6, 9, 10]
  ]

].map(([nombre, posiciones]) =>
  Object.freeze({
    nombre,
    posiciones
  })
);

// Comprobar qué patrones están completos.
function patronesCompletos(tabla, cantadas) {
  return PATRONES
    .filter((patron) =>
      patron.posiciones.every((posicion) =>
        cantadas.has(tabla[posicion])
      )
    )
    .map((patron) => patron.nombre);
}

// Identificar si falta una sola carta para ganar.
function cartaQueFalta(tabla, cantadas) {

  // Si ya existe un patrón ganador,
  // no necesitamos buscar otra carta.
  if (patronesCompletos(tabla, cantadas).length > 0) {
    return null;
  }

  for (const patron of PATRONES) {

    // No utilizar la tabla llena para
    // generar avisos de "¡Casi!".
    if (patron.nombre === 'llena') {
      continue;
    }

    // Buscar las cartas que todavía faltan.
    const faltan = patron.posiciones
      .map((posicion) => tabla[posicion])
      .filter((id) => !cantadas.has(id));

    // Si falta exactamente una carta,
    // devolver su identificador.
    if (faltan.length === 1) {
      return faltan[0];
    }
  }

  // No existe un patrón cercano a completarse.
  return null;
}

// Convertir el nombre del patrón en una descripción.
function describirPatron(nombre) {

  if (nombre === 'llena') {
    return 'la tabla llena';
  }

  if (nombre === 'esquinas') {
    return 'las cuatro esquinas';
  }

  if (nombre === 'centro') {
    return 'el centro';
  }

  if (nombre.startsWith('diagonal')) {
    return 'una diagonal';
  }

  const resultado = /^(fila|columna)(\d)$/.exec(nombre);

  return resultado
    ? `la ${resultado[1]} ${resultado[2]}`
    : nombre;
}

// Exportar las funciones para las pruebas
// y el servidor de Lotería Push.
module.exports = {
  PATRONES,
  patronesCompletos,
  cartaQueFalta,
  describirPatron
};
