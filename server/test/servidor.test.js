
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { crearServidor } = require('../servidor');
const { Salas } = require('../sala');
const { patronesCompletos } = require('../lineas');

// Fuente de azar para obtener resultados reproducibles.
function fuenteDeterminista() {
  let s = 500;
  let c = 0;

  return {
    semilla: () => ++s,
    clave: () => `clave${++c}`,
    codigoSala: () => `SALA${++c}`
  };
}

// Iniciar un servidor de prueba en un puerto libre.
async function levantar({ falla = () => null } = {}) {
  const enviados = [];
  const logs = [];
  let reloj = 1_000_000;

  const enviador = {
    async enviar(mensaje) {
      const error = falla(mensaje);

      if (error) {
        throw error;
      }

      enviados.push(mensaje);
      return 'id';
    }
  };

  const salas = new Salas({
    fuente: fuenteDeterminista()
  });

  const srv = crearServidor({
    salas,
    enviador,
    ahora: () => reloj,
    log: (mensaje) => logs.push(mensaje)
  });

  await new Promise((resolver) =>
    srv.listen(0, resolver)
  );

  const base = `http://127.0.0.1:${srv.address().port}`;

  // Realizar peticiones HTTP al servidor.
  const http = async (
    metodo,
    ruta,
    cuerpo,
    cabeceras = {}
  ) => {
    const respuesta = await fetch(base + ruta, {
      method: metodo,
      headers: {
        'content-type': 'application/json',
        ...cabeceras
      },
      body: cuerpo === undefined
        ? undefined
        : typeof cuerpo === 'string'
          ? cuerpo
          : JSON.stringify(cuerpo)
    });

    return {
      estado: respuesta.status,
      json: await respuesta.json()
    };
  };

  return {
    http,
    enviados,
    logs,
    salas,
    avanzar: (ms) => {
      reloj += ms;
    },
    cerrar: () => new Promise((resolver) =>
      srv.close(resolver)
    )
  };
}

const T1 = 'token-ana-xxxxxxxxxxxxxxxxxxxx';
const T2 = 'token-beto-xxxxxxxxxxxxxxxxxxx';

// Crear una sala mediante HTTP.
async function sala(ctx) {
  const { json } = await ctx.http('POST', '/salas');

  return {
    id: json.id,
    cantor: {
      'x-cantor-clave': json.claveCantor
    }
  };
}

// Prueba 1.
test('flujo completo: crear, unirse, cantar y enviar push', async () => {
  const ctx = await levantar();

  try {
    const s = await sala(ctx);

    const u = await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      {
        nombre: 'Ana',
        destino: {
          tipo: 'token',
          valor: T1
        }
      }
    );

    assert.equal(u.estado, 201);
    assert.equal(u.json.tabla.length, 16);

    const c = await ctx.http(
      'POST',
      `/salas/${s.id}/cantar`,
      undefined,
      s.cantor
    );

    assert.equal(c.estado, 200);
    assert.equal(c.json.evento.n, 1);
    assert.equal(ctx.enviados.length, 1);

    assert.equal(
      ctx.enviados[0].topic,
      `sala_${s.id}`
    );

    assert.equal(ctx.enviados[0].data.n, '1');
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 2.
test('cantar exige la clave del cantor', async () => {
  const ctx = await levantar();

  try {
    const s = await sala(ctx);

    const sinClave = await ctx.http(
      'POST',
      `/salas/${s.id}/cantar`
    );

    const mala = await ctx.http(
      'POST',
      `/salas/${s.id}/cantar`,
      undefined,
      { 'x-cantor-clave': 'adivinada' }
    );

    assert.equal(sinClave.estado, 403);
    assert.equal(mala.estado, 403);
    assert.equal(ctx.enviados.length, 0);
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 3.
test('dos cantos seguidos se rechazan con 429', async () => {
  const ctx = await levantar();

  try {
    const s = await sala(ctx);

    await ctx.http(
      'POST',
      `/salas/${s.id}/cantar`,
      undefined,
      s.cantor
    );

    const r = await ctx.http(
      'POST',
      `/salas/${s.id}/cantar`,
      undefined,
      s.cantor
    );

    assert.equal(r.estado, 429);
    assert.equal(r.json.error, 'MUY_RAPIDO');
    assert.equal(ctx.enviados.length, 1);

    ctx.avanzar(2500);

    const siguiente = await ctx.http(
      'POST',
      `/salas/${s.id}/cantar`,
      undefined,
      s.cantor
    );

    assert.equal(siguiente.estado, 200);
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 4.
test('consultar las cartas cantadas desde un número', async () => {
  const ctx = await levantar();

  try {
    const s = await sala(ctx);

    for (let i = 0; i < 4; i++) {
      await ctx.http(
        'POST',
        `/salas/${s.id}/cantar`,
        undefined,
        s.cantor
      );

      ctx.avanzar(3000);
    }

    const e = await ctx.http(
      'GET',
      `/salas/${s.id}/estado?desde=2`
    );

    assert.equal(e.json.ultima, 4);

    assert.deepEqual(
      e.json.cartas.map((c) => c.n),
      [3, 4]
    );

    const raro = await ctx.http(
      'GET',
      `/salas/${s.id}/estado?desde=abc`
    );

    assert.equal(raro.json.cartas.length, 4);
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 5.
test('si Firebase falla, el canto sigue contando', async () => {
  const ctx = await levantar({
    falla: () => Object.assign(
      new Error('FCM caído'),
      { code: 'messaging/internal-error' }
    )
  });

  try {
    const s = await sala(ctx);

    const c = await ctx.http(
      'POST',
      `/salas/${s.id}/cantar`,
      undefined,
      s.cantor
    );

    assert.equal(c.estado, 200);
    assert.equal(c.json.enviado, false);

    assert.ok(
      ctx.logs.some((l) =>
        l.includes('messaging/internal-error')
      )
    );

    const e = await ctx.http(
      'GET',
      `/salas/${s.id}/estado`
    );

    assert.equal(e.json.ultima, 1);
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 6.
test('el aviso de casi es personal y elimina tokens muertos', async () => {
  const muerto = Object.assign(
    new Error('Token inválido'),
    {
      code: 'messaging/registration-token-not-registered'
    }
  );

  const ctx = await levantar({
    falla: (m) => m.token === T2 ? muerto : null
  });

  try {
    const s = await sala(ctx);

    await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      {
        nombre: 'Ana',
        destino: { tipo: 'token', valor: T1 }
      }
    );

    await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      {
        nombre: 'Beto',
        destino: { tipo: 'token', valor: T2 }
      }
    );

    for (let i = 0; i < 40; i++) {
      const r = await ctx.http(
        'POST',
        `/salas/${s.id}/cantar`,
        undefined,
        s.cantor
      );

      if (r.estado !== 200) {
        break;
      }

      ctx.avanzar(3000);
    }

    const personales = ctx.enviados.filter(
      (m) => m.token
    );

    assert.ok(
      personales.every(
        (m) => m.topic === undefined &&
               m.data.tipo === 'casi'
      )
    );

    assert.ok(
      personales.every((m) => m.token === T1)
    );

    assert.equal(
      ctx.salas.obtener(s.id)
        .jugadores.get('Beto').destino,
      null
    );

    assert.ok(
      ctx.logs.some((l) =>
        l.includes('destino muerto de Beto')
      )
    );
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 7.
test('invalid-argument no elimina al jugador', async () => {
  const raro = Object.assign(
    new Error('Mensaje incorrecto'),
    { code: 'messaging/invalid-argument' }
  );

  const ctx = await levantar({
    falla: (m) => m.token ? raro : null
  });

  try {
    const s = await sala(ctx);

    await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      {
        nombre: 'Ana',
        destino: { tipo: 'token', valor: T1 }
      }
    );

    for (let i = 0; i < 40; i++) {
      await ctx.http(
        'POST',
        `/salas/${s.id}/cantar`,
        undefined,
        s.cantor
      );

      ctx.avanzar(3000);
    }

    assert.notEqual(
      ctx.salas.obtener(s.id)
        .jugadores.get('Ana').destino,
      null
    );
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 8.
test('un destino FID utiliza el campo fid', async () => {
  const ctx = await levantar();

  try {
    const s = await sala(ctx);

    await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      {
        nombre: 'Ana',
        destino: {
          tipo: 'fid',
          valor: 'fid-ana-xxxxxxxxxxxxxxxxxxxxx'
        }
      }
    );

    for (let i = 0; i < 40; i++) {
      await ctx.http(
        'POST',
        `/salas/${s.id}/cantar`,
        undefined,
        s.cantor
      );

      ctx.avanzar(3000);
    }

    const personal = ctx.enviados.find(
      (m) => m.fid
    );

    assert.ok(personal);
    assert.equal(personal.token, undefined);
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 9.
test('actualizar destino exige la clave del jugador', async () => {
  const ctx = await levantar();

  try {
    const s = await sala(ctx);

    const u = await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      {
        nombre: 'Ana',
        destino: { tipo: 'token', valor: T1 }
      }
    );

    const nuevo = {
      nombre: 'Ana',
      destino: { tipo: 'token', valor: T2 }
    };

    const incorrecta = await ctx.http(
      'PUT',
      `/salas/${s.id}/destino`,
      nuevo,
      { 'x-jugador-clave': 'robada' }
    );

    assert.equal(incorrecta.estado, 403);

    const correcta = await ctx.http(
      'PUT',
      `/salas/${s.id}/destino`,
      nuevo,
      { 'x-jugador-clave': u.json.claveJugador }
    );

    assert.equal(correcta.estado, 200);

    assert.equal(
      ctx.salas.obtener(s.id)
        .jugadores.get('Ana').destino.valor,
      T2
    );
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 10.
test('el servidor valida la lotería y anuncia al ganador', async () => {
  const ctx = await levantar();

  try {
    const s = await sala(ctx);

    const u = await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      {
        nombre: 'Ana',
        destino: { tipo: 'token', valor: T1 }
      }
    );

    const cabecera = {
      'x-jugador-clave': u.json.claveJugador
    };

    // Primero comprobar una falsa alarma.
    const falsa = await ctx.http(
      'POST',
      `/salas/${s.id}/loteria`,
      { nombre: 'Ana' },
      cabecera
    );

    assert.equal(falsa.json.gano, false);

    assert.equal(
      ctx.enviados.filter(
        (m) => m.data.tipo === 'loteria'
      ).length,
      0
    );

    // Cantar cartas hasta completar un patrón.
    const ids = new Set();

    for (let i = 0; i < 54; i++) {
      const r = await ctx.http(
        'POST',
        `/salas/${s.id}/cantar`,
        undefined,
        s.cantor
      );

      ids.add(r.json.evento.cartaId);
      ctx.avanzar(3000);

      if (
        patronesCompletos(
          u.json.tabla,
          ids
        ).length > 0
      ) {
        break;
      }
    }

    const buena = await ctx.http(
      'POST',
      `/salas/${s.id}/loteria`,
      { nombre: 'Ana' },
      cabecera
    );

    assert.equal(buena.json.gano, true);

    const fin = ctx.enviados.filter(
      (m) => m.data.tipo === 'loteria'
    );

    assert.equal(fin.length, 1);
    assert.equal(fin[0].topic, `sala_${s.id}`);

    const otra = await ctx.http(
      'POST',
      `/salas/${s.id}/loteria`,
      { nombre: 'Ana' },
      cabecera
    );

    assert.equal(otra.estado, 409);
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 11.
test('rechaza JSON incorrecto, cuerpos grandes y rutas inexistentes', async () => {
  const ctx = await levantar();

  try {
    const s = await sala(ctx);

    const jsonRoto = await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      '{no es json'
    );

    assert.equal(jsonRoto.estado, 400);

    const arreglo = await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      '[1,2]'
    );

    assert.equal(arreglo.estado, 400);

    const grande = await ctx.http(
      'POST',
      `/salas/${s.id}/unirse`,
      { nombre: 'x'.repeat(5000) }
    );

    assert.equal(grande.estado, 413);

    const inexistente = await ctx.http(
      'GET',
      '/salas/ZZZZZ/estado'
    );

    assert.equal(inexistente.estado, 404);

    const desconocida = await ctx.http(
      'GET',
      '/otra/cosa'
    );

    assert.equal(desconocida.estado, 404);
  } finally {
    await ctx.cerrar();
  }
});

// Prueba 12.
test('los errores internos no muestran información privada', async () => {
  const ctx = await levantar();

  try {
    ctx.salas.crear = () => {
      throw new Error(
        'contraseña de la base de datos: 1234'
      );
    };

    const r = await ctx.http(
      'POST',
      '/salas'
    );

    assert.equal(r.estado, 500);

    assert.equal(
      JSON.stringify(r.json).includes('contraseña'),
      false
    );

    assert.ok(
      ctx.logs.some((l) =>
        l.includes('contraseña')
      )
    );
  } finally {
    await ctx.cerrar();
  }
});
