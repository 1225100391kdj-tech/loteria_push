
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  patronesCompletos,
  cartaQueFalta,
  describirPatron,
  PATRONES
} = require('../lineas');

// Tabla de ejemplo con las cartas del 1 al 16.
const tabla = Array.from(
  { length: 16 },
  (_, i) => i + 1
);

// Comprobar patrones con las cartas cantadas.
const comp = (...ids) =>
  patronesCompletos(tabla, new Set(ids));

// Prueba 1.
test('hay 13 patrones ganadores', () => {
  assert.equal(PATRONES.length, 13);
});

// Prueba 2.
test('sin cartas cantadas no hay patrón', () => {
  assert.deepEqual(comp(), []);
});

// Prueba 3.
test('completar la primera fila', () => {
  assert.deepEqual(
    comp(1, 2, 3, 4),
    ['fila1']
  );
});

// Prueba 4.
test('completar la primera columna', () => {
  assert.deepEqual(
    comp(1, 5, 9, 13),
    ['columna1']
  );
});

// Prueba 5.
test('completar la primera diagonal', () => {
  assert.deepEqual(
    comp(1, 6, 11, 16),
    ['diagonal1']
  );
});

// Prueba 6.
test('completar la segunda diagonal', () => {
  assert.deepEqual(
    comp(4, 7, 10, 13),
    ['diagonal2']
  );
});

// Prueba 7.
test('completar las cuatro esquinas', () => {
  assert.deepEqual(
    comp(1, 4, 13, 16),
    ['esquinas']
  );
});

// Prueba 8.
test('completar el centro', () => {
  assert.deepEqual(
    comp(6, 7, 10, 11),
    ['centro']
  );
});

// Prueba 9.
test('una carta de menos no cuenta', () => {
  assert.deepEqual(
    comp(1, 2, 3),
    []
  );
});

// Prueba 10.
test('ignorar cartas que no están en la tabla', () => {
  assert.deepEqual(
    comp(1, 2, 3, 40, 50),
    []
  );
});

// Prueba 11.
test('tabla llena incluye todos los patrones', () => {
  const todas = Array.from(
    { length: 16 },
    (_, i) => i + 1
  );

  const resultado = comp(...todas);

  assert.equal(resultado[0], 'llena');
  assert.equal(resultado.length, 13);
});

// Prueba 12.
test('detectar carta faltante en una fila', () => {
  assert.equal(
    cartaQueFalta(tabla, new Set([1, 2, 3])),
    4
  );
});

// Prueba 13.
test('detectar carta faltante en diagonal', () => {
  assert.equal(
    cartaQueFalta(tabla, new Set([1, 6, 11])),
    16
  );
});

// Prueba 14.
test('sin patrón cercano devuelve null', () => {
  assert.equal(
    cartaQueFalta(tabla, new Set()),
    null
  );
});

// Prueba 15.
test('si ya ganó no necesita otra carta', () => {
  assert.equal(
    cartaQueFalta(tabla, new Set([1, 2, 3, 4])),
    null
  );
});

// Prueba 16.
test('descripciones de los patrones', () => {
  assert.equal(
    describirPatron('fila2'),
    'la fila 2'
  );

  assert.equal(
    describirPatron('columna4'),
    'la columna 4'
  );

  assert.equal(
    describirPatron('diagonal2'),
    'una diagonal'
  );

  assert.equal(
    describirPatron('esquinas'),
    'las cuatro esquinas'
  );

  assert.equal(
    describirPatron('llena'),
    'la tabla llena'
  );
});
