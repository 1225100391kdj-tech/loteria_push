
'use strict';

const http = require('node:http');

const {
  Salas,
  ErrorJuego,
  INTERVALO_MIN_CANTO_MS
} = require('./sala');

const {
  mensajeCarta,
  mensajeCasi,
  mensajeLoteria,
  haciaDestino
} = require('./mensajes');

const {
  crearEnviadorConsola,
  crearEnviadorFcm,
  esDestinoMuerto
} = require('./enviador');

// Tamaño máximo permitido para las peticiones.
const MAX_CUERPO = 2048;

// Leer el contenido JSON de una petición.
function leerJson(req) {
  return new Promise((resolve, reject) => {
    let total = 0;
    const partes = [];

    req.on('data', (fragmento) => {
      total += fragmento.length;

      // Rechazar peticiones demasiado grandes.
      if (total > MAX_CUERPO) {
        req.removeAllListeners('data');
        req.resume();

        reject(
          new ErrorJuego(
            'CUERPO_GRANDE',
            'Cuerpo demasiado grande',
            413
          )
        );

        return;
      }

      partes.push(fragmento);
    });

    req.on('end', () => {
      if (partes.length === 0) {
        return resolve({});
      }

      try {
        const datos = JSON.parse(
          Buffer.concat(partes).toString('utf8')
        );

        // Solo se aceptan objetos JSON.
        if (
          datos === null ||
          typeof datos !== 'object' ||
          Array.isArray(datos)
        ) {
          throw new Error('JSON no válido');
        }

        resolve(datos);
      } catch {
        reject(
          new ErrorJuego(
            'JSON_INVALIDO',
            'El cuerpo no es JSON válido',
            400
          )
        );
      }
    });

    req.on('error', reject);
  });
}

// Crear el controlador de peticiones HTTP.
function crearManejador({
  salas = new Salas(),
  enviador = crearEnviadorConsola(),
  ahora = () => Date.now(),
  log = () => {}
} = {}) {

  // Intentar enviar un push sin detener la partida.
  async function enviarSeguro(
    mensaje,
    { sala, jugador } = {}
  ) {
    try {
      await enviador.enviar(mensaje);
      return true;
    } catch (error) {

      // Eliminar únicamente destinos que ya no existen.
      if (
        jugador &&
        esDestinoMuerto(error)
      ) {
        sala.quitarDestino(jugador);

        log(
          `destino muerto de ${jugador}: ` +
          `eliminado (${error.code})`
        );
      } else {
        log(
          `fallo al enviar (${error && error.code}): ` +
          `${error && error.message}`
        );
      }

      return false;
    }
  }

  // Atender las solicitudes del cliente.
  async function atender(req) {
    const url = new URL(
      req.url,
      'http://localhost'
    );

    const ruta = url.pathname.replace(/\/+$/, '');
    const metodo = req.method;

    // Crear una sala nueva.
    if (
      metodo === 'POST' &&
      ruta === '/salas'
    ) {
      const sala = salas.crear();

      return [
        201,
        {
          id: sala.id,
          claveCantor: sala.claveCantor
        }
      ];
    }

    // Obtener el código y la acción de la sala.
    const coincidencia =
      /^\/salas\/([A-Za-z0-9]{3,8})(\/[a-z]+)?$/.exec(ruta);

    if (!coincidencia) {
      throw new ErrorJuego(
        'RUTA_NO_EXISTE',
        'Ruta no encontrada',
        404
      );
    }

    const sala = salas.obtener(coincidencia[1]);
    const accion = coincidencia[2] ?? '';

    // Registrar un jugador.
    if (
      metodo === 'POST' &&
      accion === '/unirse'
    ) {
      const cuerpo = await leerJson(req);

      const jugador = sala.unir(
        cuerpo.nombre,
        cuerpo.destino
      );

      return [201, jugador];
    }

    // Actualizar destino de notificaciones.
    if (
      metodo === 'PUT' &&
      accion === '/destino'
    ) {
      const cuerpo = await leerJson(req);

      sala.actualizarDestino(
        cuerpo.nombre,
        req.headers['x-jugador-clave'],
        cuerpo.destino
      );

      return [
        200,
        { ok: true }
      ];
    }

    // Consultar cartas cantadas.
    if (
      metodo === 'GET' &&
      accion === '/estado'
    ) {
      const desde = Number.parseInt(
        url.searchParams.get('desde') ?? '0',
        10
      );

      const inicio = Number.isNaN(desde)
        ? 0
        : desde;

      return [
        200,
        sala.estado(inicio)
      ];
    }

    // Cantar la siguiente carta.
    if (
      metodo === 'POST' &&
      accion === '/cantar'
    ) {
      // Solamente el cantor puede sacar cartas.
      sala.verificarCantor(
        req.headers['x-cantor-clave']
      );

      const {
        evento,
        casi
      } = sala.cantar(ahora());

      const tiempo = ahora();

      // Enviar la carta a toda la sala.
      const enviado = await enviarSeguro(
        mensajeCarta(evento, tiempo),
        { sala }
      );

      // Enviar avisos personales de "¡Casi!".
      await Promise.all(
        casi.map((aviso) =>
          enviarSeguro(
            haciaDestino(
              mensajeCasi(aviso.evento, tiempo),
              aviso.destino
            ),
            {
              sala,
              jugador: aviso.jugador
            }
          )
        )
      );

      return [
        200,
        {
          evento,
          enviado,
          avisosCasi: casi.length
        }
      ];
    }

    // Reclamar una victoria.
    if (
      metodo === 'POST' &&
      accion === '/loteria'
    ) {
      const cuerpo = await leerJson(req);

      // El servidor comprueba si ganó realmente.
      const resultado = sala.reclamar(
        cuerpo.nombre,
        req.headers['x-jugador-clave']
      );

      // Avisar a todos si existe un ganador.
      if (resultado.gano) {
        await enviarSeguro(
          mensajeLoteria(
            resultado.evento,
            ahora()
          ),
          { sala }
        );
      }

      return [
        200,
        {
          gano: resultado.gano,
          patron: resultado.patron ?? null
        }
      ];
    }

    throw new ErrorJuego(
      'RUTA_NO_EXISTE',
      'Ruta no encontrada',
      404
    );
  }

  // Enviar la respuesta HTTP al cliente.
  return async (req, res) => {
    try {
      const [estado, cuerpo] = await atender(req);

      res.writeHead(estado, {
        'content-type':
          'application/json; charset=utf-8'
      });

      res.end(JSON.stringify(cuerpo));

    } catch (error) {
      const conocido = error instanceof ErrorJuego;

      // Registrar los errores inesperados.
      if (!conocido) {
        log(`error interno: ${error && error.stack}`);
      }

      // Nunca mostrar detalles internos al cliente.
      const cabeceras = {
        'content-type':
          'application/json; charset=utf-8'
      };

      if (conocido && error.estado === 413) {
        cabeceras.connection = 'close';
      }

      res.writeHead(
        conocido ? error.estado : 500,
        cabeceras
      );

      res.end(
        JSON.stringify({
          error: conocido
            ? error.codigo
            : 'ERROR_INTERNO',

          mensaje: conocido
            ? error.message
            : 'Error interno'
        })
      );
    }
  };
}

// Crear el servidor HTTP de Node.js.
function crearServidor(dependencias) {
  return http.createServer(
    crearManejador(dependencias)
  );
}

// Ejecutar el servidor solamente cuando
// este archivo se abre directamente con Node.js.
if (require.main === module) {
  const log = (...datos) =>
    console.log(
      new Date().toISOString(),
      ...datos
    );

  const real = process.env.FCM_REAL === '1';

  // Utilizar Firebase real o simulado.
  const enviador = real
    ? crearEnviadorFcm({
        dryRun: process.env.FCM_DRY_RUN === '1'
      })
    : crearEnviadorConsola(log);

  const puerto = Number(
    process.env.PORT ?? 8080
  );

  crearServidor({
    enviador,
    log
  }).listen(puerto, () => {
    log(
      `Cantor listo en http://localhost:${puerto} ` +
      `(${real ? 'FCM real' : 'push simulado en consola'}; ` +
      `intervalo mínimo ${INTERVALO_MIN_CANTO_MS} ms)`
    );
  });
}

// Exportar las funciones para las pruebas.
module.exports = {
  crearManejador,
  crearServidor
};
