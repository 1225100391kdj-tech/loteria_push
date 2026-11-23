
'use strict';

const crypto = require('node:crypto');

const {
  barajar,
  generarTabla,
  cartaPorId
} = require('./baraja');

const {
  patronesCompletos,
  cartaQueFalta
} = require('./lineas');

// Errores personalizados del juego.
class ErrorJuego extends Error {
  constructor(codigo, mensaje, estado = 400) {
    super(mensaje);
    this.codigo = codigo;
    this.estado = estado;
  }
}

// Límites de las partidas.
const MAX_JUGADORES = 30;
const MAX_SALAS = 200;
const INTERVALO_MIN_CANTO_MS = 2000;

// Caracteres permitidos para los códigos de sala.
const ALFABETO = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

// Generar valores seguros para partidas reales.
const fuenteSegura = {
  semilla: () => crypto.randomInt(0, 2 ** 31),

  clave: () =>
    crypto.randomBytes(16).toString('hex'),

  codigoSala: () =>
    Array.from(
      { length: 5 },
      () => ALFABETO[crypto.randomInt(ALFABETO.length)]
    ).join('')
};

// Comparar claves de manera segura.
function iguales(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));

  return x.length === y.length &&
    crypto.timingSafeEqual(x, y);
}

// Validar el nombre de un jugador.
function validarNombre(nombre) {
  if (typeof nombre !== 'string') {
    throw new ErrorJuego(
      'NOMBRE_INVALIDO',
      'El nombre es obligatorio'
    );
  }

  const limpio = nombre.trim();

  if (!/^[\p{L}\p{N} ._-]{1,20}$/u.test(limpio)) {
    throw new ErrorJuego(
      'NOMBRE_INVALIDO',
      'El nombre debe tener de 1 a 20 letras, números o espacios'
    );
  }

  return limpio;
}

// Validar el destino de las notificaciones.
function validarDestino(destino) {
  // Se puede jugar sin activar notificaciones.
  if (destino === null || destino === undefined) {
    return null;
  }

  const ok =
    typeof destino === 'object' &&
    (destino.tipo === 'token' || destino.tipo === 'fid') &&
    typeof destino.valor === 'string' &&
    destino.valor.length >= 20 &&
    destino.valor.length <= 4096;

  if (!ok) {
    throw new ErrorJuego(
      'DESTINO_INVALIDO',
      'El destino de notificaciones no es válido'
    );
  }

  return {
    tipo: destino.tipo,
    valor: destino.valor
  };
}

// Clase que controla una partida de lotería.
class Sala {
  constructor({
    id,
    claveCantor,
    semilla,
    fuente = fuenteSegura
  }) {
    this.id = id;
    this.claveCantor = claveCantor;
    this.fuente = fuente;

    // El mazo permanece secreto en el servidor.
    this._mazo = barajar(semilla);

    // Cartas que ya fueron cantadas.
    this.cantadas = [];

    // Jugadores registrados en la sala.
    this.jugadores = new Map();

    this.ganador = null;
    this.patron = null;

    this._ultimoCantoMs = -Infinity;
  }

  // Cantidad de cartas que han salido.
  get ultima() {
    return this.cantadas.length;
  }

  // Obtener copias de las cartas cantadas.
  _cartasDesde(desde) {
    return this.cantadas
      .slice(Math.max(0, desde))
      .map((carta) => ({ ...carta }));
  }

  // Agregar un jugador a la sala.
  unir(nombre, destino) {
    const limpio = validarNombre(nombre);
    const dest = validarDestino(destino);

    if (this.jugadores.has(limpio)) {
      throw new ErrorJuego(
        'NOMBRE_OCUPADO',
        'Ya hay alguien con ese nombre',
        409
      );
    }

    if (this.jugadores.size >= MAX_JUGADORES) {
      throw new ErrorJuego(
        'SALA_LLENA',
        'La sala está llena',
        409
      );
    }

    const claveJugador = this.fuente.clave();
    const tabla = generarTabla(this.fuente.semilla());

    this.jugadores.set(limpio, {
      nombre: limpio,
      tabla,
      claveJugador,
      destino: dest,
      avisadoCasi: false
    });

    return {
      nombre: limpio,
      tabla,
      claveJugador,
      ultima: this.ultima,
      cartas: this._cartasDesde(0)
    };
  }

  // Verificar la identidad de un jugador.
  _jugador(nombre, clave) {
    const jugador = this.jugadores.get(nombre);

    if (
      !jugador ||
      !iguales(jugador.claveJugador, clave ?? '')
    ) {
      throw new ErrorJuego(
        'NO_AUTORIZADO',
        'Credenciales inválidas',
        403
      );
    }

    return jugador;
  }

  // Actualizar el token de notificaciones.
  actualizarDestino(nombre, clave, destino) {
    const jugador = this._jugador(nombre, clave);

    jugador.destino = validarDestino(destino);
  }

  // Desactivar notificaciones para un jugador.
  quitarDestino(nombre) {
    const jugador = this.jugadores.get(nombre);

    if (jugador) {
      jugador.destino = null;
    }
  }

  // Comprobar la clave del cantor.
  verificarCantor(clave) {
    if (!iguales(this.claveCantor, clave ?? '')) {
      throw new ErrorJuego(
        'NO_AUTORIZADO',
        'Solo el cantor puede hacer eso',
        403
      );
    }
  }

  // Cantar la siguiente carta.
  cantar(ahoraMs) {
    // No continuar si ya existe un ganador.
    if (this.ganador) {
      throw new ErrorJuego(
        'SALA_TERMINADA',
        'La partida ya terminó',
        409
      );
    }

    // Comprobar si quedan cartas.
    if (this.ultima >= this._mazo.length) {
      throw new ErrorJuego(
        'SIN_CARTAS',
        'Ya se cantaron todas las cartas',
        409
      );
    }

    // Respetar dos segundos entre cartas.
    if (
      ahoraMs - this._ultimoCantoMs <
      INTERVALO_MIN_CANTO_MS
    ) {
      throw new ErrorJuego(
        'MUY_RAPIDO',
        'Canta más despacio',
        429
      );
    }

    this._ultimoCantoMs = ahoraMs;

    // Obtener la siguiente carta del mazo.
    const carta = cartaPorId(
      this._mazo[this.ultima]
    );

    // Registrar la carta cantada.
    this.cantadas.push({
      n: this.ultima + 1,
      cartaId: carta.id,
      nombre: carta.nombre,
      pista: carta.pista
    });

    // Crear el evento de la carta.
    const evento = {
      tipo: 'carta',
      sala: this.id,
      n: this.ultima,
      cartaId: carta.id,
      nombre: carta.nombre,
      pista: carta.pista
    };

    // Revisar qué cartas han salido.
    const ids = new Set(
      this.cantadas.map((c) => c.cartaId)
    );

    // Avisos personales de "¡Casi!".
    const casi = [];

    for (const jugador of this.jugadores.values()) {
      // Enviar como máximo un aviso por jugador.
      if (jugador.avisadoCasi) {
        continue;
      }

      const falta = cartaQueFalta(
        jugador.tabla,
        ids
      );

      if (falta !== null) {
        jugador.avisadoCasi = true;

        // Solo avisar a quien tenga un destino.
        if (jugador.destino) {
          casi.push({
            jugador: jugador.nombre,
            destino: jugador.destino,
            evento: {
              tipo: 'casi',
              sala: this.id,
              n: this.ultima,
              cartaId: falta
            }
          });
        }
      }
    }

    return {
      evento,
      casi
    };
  }

  // Un jugador reclama que ganó la partida.
  reclamar(nombre, clave) {
    const jugador = this._jugador(nombre, clave);

    // Solo puede existir un ganador.
    if (this.ganador) {
      throw new ErrorJuego(
        'YA_HAY_GANADOR',
        `${this.ganador} ya cantó Lotería`,
        409
      );
    }

    const ids = new Set(
      this.cantadas.map((c) => c.cartaId)
    );

    // Comprobar que realmente completó un patrón.
    const patrones = patronesCompletos(
      jugador.tabla,
      ids
    );

    if (patrones.length === 0) {
      return {
        gano: false,
        evento: null
      };
    }

    // Registrar al ganador.
    this.ganador = jugador.nombre;
    this.patron = patrones[0];

    return {
      gano: true,
      patron: this.patron,
      evento: {
        tipo: 'loteria',
        sala: this.id,
        n: this.ultima,
        ganador: jugador.nombre,
        patron: this.patron
      }
    };
  }

  // Consultar el estado público de la partida.
  estado(desde = 0) {
    return {
      sala: this.id,
      ultima: this.ultima,
      cartas: this._cartasDesde(desde),
      ganador: this.ganador,
      patron: this.patron
    };
  }
}

// Clase que administra todas las salas.
class Salas {
  constructor({ fuente = fuenteSegura } = {}) {
    this.fuente = fuente;
    this._salas = new Map();
  }

  // Crear una nueva sala.
  crear() {
    if (this._salas.size >= MAX_SALAS) {
      throw new ErrorJuego(
        'SERVIDOR_LLENO',
        'Demasiadas salas activas',
        503
      );
    }

    let id;

    // Evitar códigos de sala repetidos.
    do {
      id = this.fuente.codigoSala();
    } while (this._salas.has(id));

    const sala = new Sala({
      id,
      claveCantor: this.fuente.clave(),
      semilla: this.fuente.semilla(),
      fuente: this.fuente
    });

    this._salas.set(id, sala);

    return sala;
  }

  // Buscar una sala por su código.
  obtener(id) {
    const sala = this._salas.get(
      String(id).toUpperCase()
    );

    if (!sala) {
      throw new ErrorJuego(
        'SALA_NO_EXISTE',
        'No existe esa sala',
        404
      );
    }

    return sala;
  }
}

// Exportar las clases y constantes.
module.exports = {
  Sala,
  Salas,
  ErrorJuego,
  fuenteSegura,
  MAX_JUGADORES,
  INTERVALO_MIN_CANTO_MS
};
