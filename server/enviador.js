
'use strict';

// Este archivo se encarga de enviar las
// notificaciones de Lotería Push.

// Enviador de prueba.
// Muestra las notificaciones en la terminal
// sin enviarlas realmente por Firebase.
function crearEnviadorConsola(log = console.log) {
  return {
    async enviar(mensaje) {
      log(
        '[push simulado]',
        JSON.stringify(mensaje)
      );

      return 'simulado';
    }
  };
}

// Enviador real mediante Firebase Cloud Messaging.
function crearEnviadorFcm({ dryRun = false } = {}) {
  // Firebase Admin solamente se carga
  // cuando se utiliza el enviador real.
  const admin = require('firebase-admin');

  // Inicializar Firebase.
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  const messaging = admin.messaging();

  return {
    enviar: (mensaje) =>
      messaging.send(mensaje, dryRun)
  };
}

// Comprobar si un token ya no es válido.
function esDestinoMuerto(error) {
  const codigo = error && error.code;

  return (
    codigo ===
      'messaging/registration-token-not-registered' ||
    codigo ===
      'messaging/invalid-registration-token'
  );
}

// Exportar las funciones.
module.exports = {
  crearEnviadorConsola,
  crearEnviadorFcm,
  esDestinoMuerto
};
