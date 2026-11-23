
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  CARTAS,
  barajar,
  generarTabla,
  cartaPorId
} = require('../baraja');

// Prueba 1: Verificar las 54 cartas.
test('hay 54 cartas con ids 1..54, nombres y pistas únicos', () => {
  assert.equal(CARTAS.length, 54);

  assert.deepEqual(
    CARTAS.map((c) => c.id),
    Array.from({ length: 54 }, (_, i) => i + 1)
  );

  assert.equal(
    new Set(CARTAS.map((c) => c.nombre)).size,
    54
  );

  assert.equal(
    new Set(CARTAS.map((c) => c.pista)).size,
    54
  );
});

// Prueba 2: Comprobar los nombres de las cartas.
test('decisión de inclusión: no hay cartas con nombres ofensivos', () => {
  const nombres = CARTAS.map((c) => c.nombre).join('|');

  assert.ok(!/Negrito|Apache/.test(nombres));

  assert.ok(
    nombres.includes('El Taco') &&
    nombres.includes('El Elote')
  );
});

// Prueba 3: Buscar cartas por identificador.
test('cartaPorId devuelve la carta o null', () => {
  assert.equal(cartaPorId(1).nombre, 'El Gallo');

  assert.equal(cartaPorId(54).nombre, 'La Rana');

  assert.equal(cartaPorId(0), null);

  assert.equal(cartaPorId(55), null);
});

// Prueba 4: Verificar que la baraja esté completa.
test('barajar es una permutación completa', () => {
  const baraja = barajar(42);

  assert.equal(baraja.length, 54);

  assert.deepEqual(
    [...baraja].sort((a, b) => a - b),
    Array.from({ length: 54 }, (_, i) => i + 1)
  );
});

// Prueba 5: Comprobar el orden de las cartas.
test('con la misma semilla sale el mismo orden; con otra, distinto', () => {
  assert.deepEqual(
    barajar(7),
    barajar(7)
  );

  assert.notDeepEqual(
    barajar(7),
    barajar(8)
  );
});

// Prueba 6: Generar una tabla de lotería.
test('la tabla tiene 16 cartas distintas y válidas', () => {
  const tabla = generarTabla(123);

  assert.equal(tabla.length, 16);

  assert.equal(
    new Set(tabla).size,
    16
  );

  assert.ok(
    tabla.every((id) => id >= 1 && id <= 54)
  );
});
