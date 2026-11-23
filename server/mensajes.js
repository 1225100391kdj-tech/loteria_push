
'use strict';

const { describirPatron } = require('./lineas');

// Límite de tamaño de los mensajes de Firebase.
const LIMITE_BYTES = 4096;

// Tiempo de duración de las notificaciones.
const TTL_CARTA_MS = 60 * 1000;
const TTL_CASI_MS = 5 * 60 * 1000;
const TTL_FIN_MS = 60 * 60 * 1000;

// Convertir los valores de los datos a texto.
function aTexto(datos) {
  return Object.fromEntries(
    Object.entries(datos).map(([clave, valor]) => [
      clave,
      String(valor)
    ])
  );
}

// Crear el nombre del tema de una sala.
function tema(sala) {
  return `sala_${sala}`;
}

// Verificar el tamaño máximo del mensaje.
function comprobarTamano(mensaje) {
  const bytes = Buffer.byteLength(
    JSON.stringify(mensaje),
    'utf8'
  );

  if (bytes > LIMITE_BYTES) {
    throw new Error(
      `Mensaje de ${bytes} bytes excede ${LIMITE_BYTES}`
    );
  }

  return mensaje;
}

// Calcular cuándo caduca la notificación.
function caduca(ahoraMs, ttlMs) {
  return String(
    Math.floor((ahoraMs + ttlMs) / 1000)
  );
}

// Crear una notificación para una carta cantada.
function mensajeCarta(evento, ahoraMs) {
  const colapso = `carta_${evento.sala}`;

  return comprobarTamano({
    topic: tema(evento.sala),

    notification: {
      title: `🃏 ${evento.nombre}`,
      body: evento.pista
    },

    data: aTexto({
      tipo: 'carta',
      sala: evento.sala,
      n: evento.n,
      cartaId: evento.cartaId,
      nombre: evento.nombre,
      pista: evento.pista
    }),

    android: {
      priority: 'high',
      ttl: TTL_CARTA_MS,
      collapseKey: colapso,

      notification: {
        channelId: 'cartas',
        tag: colapso
      }
    },

    apns: {
      headers: {
        'apns-priority': '10',
        'apns-collapse-id': colapso,
        'apns-expiration': caduca(
          ahoraMs,
          TTL_CARTA_MS
        )
      },

      payload: {
        aps: {
          sound: 'default',
          'thread-id': tema(evento.sala)
        }
      }
    }
  });
}

// Crear una notificación cuando falta una carta.
function mensajeCasi(evento, ahoraMs) {
  const colapso = `casi_${evento.sala}`;

  return comprobarTamano({
    notification: {
      title: '¡Casi! 😮',
      body:
        'Estás a UNA carta de cantar Lotería. ¡Atento!'
    },

    data: aTexto({
      tipo: 'casi',
      sala: evento.sala,
      n: evento.n,
      cartaId: evento.cartaId
    }),

    android: {
      priority: 'high',
      ttl: TTL_CASI_MS,
      collapseKey: colapso,

      notification: {
        channelId: 'momentos',
        tag: colapso
      }
    },

    apns: {
      headers: {
        'apns-priority': '10',
        'apns-collapse-id': colapso,
        'apns-expiration': caduca(
          ahoraMs,
          TTL_CASI_MS
        )
      },

      payload: {
        aps: {
          sound: 'default',
          'thread-id': tema(evento.sala)
        }
      }
    }
  });
}

// Crear una notificación cuando alguien gana.
function mensajeLoteria(evento, ahoraMs) {
  const colapso = `fin_${evento.sala}`;

  return comprobarTamano({
    topic: tema(evento.sala),

    notification: {
      title: '🎉 ¡LOTERÍA!',
      body:
        `${evento.ganador} ganó con ` +
        `${describirPatron(evento.patron)}. ` +
        '¡Felicidades!'
    },

    data: aTexto({
      tipo: 'loteria',
      sala: evento.sala,
      n: evento.n,
      ganador: evento.ganador,
      patron: evento.patron
    }),

    android: {
      priority: 'high',
      ttl: TTL_FIN_MS,
      collapseKey: colapso,

      notification: {
        channelId: 'momentos',
        tag: colapso
      }
    },

    apns: {
      headers: {
        'apns-priority': '10',
        'apns-collapse-id': colapso,
        'apns-expiration': caduca(
          ahoraMs,
          TTL_FIN_MS
        )
      },

      payload: {
        aps: {
          sound: 'default',
          'thread-id': tema(evento.sala)
        }
      }
    }
  });
}

// Dirigir un mensaje a un dispositivo específico.
function haciaDestino(mensaje, destino) {
  const base = { ...mensaje };

  // El mensaje personal ya no se envía
  // a todos los jugadores de la sala.
  delete base.topic;

  if (destino.tipo === 'fid') {
    return {
      ...base,
      fid: destino.valor
    };
  }

  return {
    ...base,
    token: destino.valor
  };
}

// Exportar las funciones.
module.exports = {
  tema,
  aTexto,
  mensajeCarta,
  mensajeCasi,
  mensajeLoteria,
  haciaDestino,
  TTL_CARTA_MS,
  TTL_CASI_MS,
  TTL_FIN_MS,
  LIMITE_BYTES
};
