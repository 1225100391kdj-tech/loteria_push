
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const m = require('../mensajes');

// Evento de ejemplo para las pruebas.
const ev = {
  tipo: 'carta',
  sala: 'ABCDE',
  n: 5,
  cartaId: 1,
  nombre: 'El Gallo',
  pista: 'Madruga más que tu mamá un domingo.'
};

const AHORA = 1_700_000_000_000;

// Prueba 1.
test('carta: va al tema de la sala', () => {
  const msg = m.mensajeCarta(ev, AHORA);

  assert.equal(msg.topic, 'sala_ABCDE');
  assert.equal(msg.token, undefined);
});

// Prueba 2.
test('data: TODOS los valores son cadenas', () => {
  const mensajes = [
    m.mensajeCarta(ev, AHORA),

    m.mensajeCasi({
      tipo: 'casi',
      sala: 'ABCDE',
      n: 7,
      cartaId: 9
    }, AHORA),

    m.mensajeLoteria({
      tipo: 'loteria',
      sala: 'ABCDE',
      n: 12,
      ganador: 'Ana',
      patron: 'fila1'
    }, AHORA)
  ];

  for (const msg of mensajes) {
    for (const [clave, valor] of Object.entries(msg.data)) {
      assert.equal(
        typeof valor,
        'string',
        `data.${clave}`
      );
    }
  }

  assert.equal(
    m.mensajeCarta(ev, AHORA).data.n,
    '5'
  );
});

// Prueba 3.
test('carta: caduca en 60 segundos', () => {
  const msg = m.mensajeCarta(ev, AHORA);

  assert.equal(
    msg.android.ttl,
    60000
  );

  assert.equal(
    msg.apns.headers['apns-expiration'],
    String(Math.floor((AHORA + 60000) / 1000))
  );
});

// Prueba 4.
test('carta: utiliza claves de colapso', () => {
  const msg = m.mensajeCarta(ev, AHORA);

  assert.equal(
    msg.android.collapseKey,
    'carta_ABCDE'
  );

  assert.equal(
    msg.android.notification.tag,
    'carta_ABCDE'
  );

  assert.equal(
    msg.apns.headers['apns-collapse-id'],
    'carta_ABCDE'
  );

  assert.ok(
    Buffer.byteLength(
      msg.apns.headers['apns-collapse-id']
    ) <= 64
  );
});

// Prueba 5.
test('las notificaciones utilizan sus canales', () => {
  assert.equal(
    m.mensajeCarta(ev, AHORA)
      .android.notification.channelId,
    'cartas'
  );

  assert.equal(
    m.mensajeCasi({
      sala: 'ABCDE',
      n: 1,
      cartaId: 1
    }, AHORA).android.notification.channelId,
    'momentos'
  );

  assert.equal(
    m.mensajeLoteria({
      sala: 'ABCDE',
      n: 1,
      ganador: 'Ana',
      patron: 'fila1'
    }, AHORA).android.notification.channelId,
    'momentos'
  );
});

// Prueba 6.
test('lotería: duración larga y texto del ganador', () => {
  const msg = m.mensajeLoteria({
    sala: 'ABCDE',
    n: 12,
    ganador: 'Ana',
    patron: 'fila1'
  }, AHORA);

  assert.equal(
    msg.android.ttl,
    3_600_000
  );

  assert.match(
    msg.notification.body,
    /Ana ganó con la fila 1/
  );
});

// Prueba 7.
test('haciaDestino: utiliza token o FID', () => {
  const base = m.mensajeCarta(ev, AHORA);

  const token = m.haciaDestino(base, {
    tipo: 'token',
    valor: 'tok'.repeat(10)
  });

  assert.equal(
    token.token,
    'tok'.repeat(10)
  );

  assert.equal(token.topic, undefined);
  assert.equal(token.fid, undefined);

  const fid = m.haciaDestino(base, {
    tipo: 'fid',
    valor: 'fid'.repeat(10)
  });

  assert.equal(
    fid.fid,
    'fid'.repeat(10)
  );

  assert.equal(fid.token, undefined);

  assert.equal(
    base.topic,
    'sala_ABCDE',
    'No debe modificar el mensaje original'
  );
});

// Prueba 8.
test('rechaza mensajes de más de 4 KB', () => {
  assert.throws(
    () => m.mensajeCarta({
      ...ev,
      pista: 'x'.repeat(5000)
    }, AHORA),
    /excede/
  );
});

// Prueba 9.
test('un mensaje normal pesa menos de 1200 bytes', () => {
  const msg = m.mensajeCarta(ev, AHORA);

  assert.ok(
    Buffer.byteLength(
      JSON.stringify(msg)
    ) < 1200
  );
});
