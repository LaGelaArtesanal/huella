const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const vision = require('@google-cloud/vision');

admin.initializeApp();
const db = admin.firestore();
const client = new vision.ImageAnnotatorClient();

// ✅ FUNCIÓN PARA 2DA GENERACIÓN
// Se especifica el bucket explícitamente: sin él, el análisis de 'firebase deploy'
// falla con "Missing bucket name" porque no puede resolver el bucket por defecto.
const STORAGE_BUCKET = 'huella2.firebasestorage.app';
exports.verifyWalkerDocuments = onObjectFinalized({ bucket: STORAGE_BUCKET }, async (event) => {
  const object = event.data;
  const filePath = object.name;
  const contentType = object.contentType;

  // 1. Validar que sea imagen y esté en la carpeta correcta
  if (!contentType || !contentType.startsWith('image/')) {
    logger.info('No es una imagen, ignorando...');
    return null;
  }
  if (!filePath.startsWith('walker_documents/')) {
    logger.info('No está en la carpeta walker_documents/, ignorando...');
    return null;
  }

  logger.info(`🔍 Procesando: ${filePath}`);

  // Estructura esperada: walker_documents/{userId}/{tipoDocumento}.jpg
  const pathParts = filePath.split('/');
  const userId = pathParts[1];
  const docType = pathParts[2] ? pathParts[2].split('.')[0] : 'unknown';

  if (!userId || docType === 'unknown') {
    logger.error('❌ No se pudo extraer userId o docType');
    return null;
  }

  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      logger.error('Usuario no encontrado en Firestore');
      return null;
    }

    const userData = userDoc.data();
    const userName = (userData.name || '').toUpperCase();
    const userLastName = (userData.lastName || '').toUpperCase();
    const userCURP = (userData.curp || '').toUpperCase();
    const userRFC = (userData.rfc || '').toUpperCase();

    let validationResult = {};

    // 2. Procesar según el tipo de documento
    switch(docType) {
      case 'ine_front':
      case 'ine_back':
        validationResult = await verifyINE(object, userName, userLastName);
        break;
      case 'acta_nacimiento':
        validationResult = await verifyActaNacimiento(object, userCURP, userName);
        break;
      case 'constancia_fiscal':
        validationResult = await verifyConstanciaFiscal(object, userRFC);
        break;
      case 'comprobante_domicilio':
        validationResult = await verifyDomicilio(object);
        break;
      case 'selfie':
        validationResult = await verifySelfie(object);
        break;
      default:
        logger.info(`📄 Tipo de documento desconocido: ${docType}`);
        return null;
    }

    // 3. Actualizar estado y verificar si todo está aprobado
    await updateDocumentStatus(userId, docType, validationResult);
    await checkAllDocumentsApproved(userId);

    return null;
  } catch (error) {
    logger.error('❌ Error en verificación:', error);
    return null;
  }
});

// ==========================================
// FUNCIONES DE VALIDACIÓN INDIVIDUAL
// ==========================================

async function verifyINE(object, userName, userLastName) {
  const bucket = admin.storage().bucket(object.bucket);
  const file = bucket.file(object.name);
  const [result] = await client.textDetection(file);
  const fullText = result.textAnnotations[0]?.description?.toUpperCase() || '';

  const nameMatch = userName && fullText.includes(userName);
  const hasINEKeyword = fullText.includes('INE') || fullText.includes('INSTITUTO NACIONAL ELECTORAL') || fullText.includes('CREDENCIAL PARA VOTAR');

  const isValid = nameMatch && hasINEKeyword;
  const reason = isValid ? 'INE verificada correctamente' : (!nameMatch ? 'El nombre no coincide con el registrado' : 'No parece ser una credencial INE válida');

  return { isValid, reason, extractedData: fullText.substring(0, 200) };
}

async function verifyActaNacimiento(object, userCURP, userName) {
  if (!userCURP || userCURP.length !== 18) return { isValid: false, reason: 'CURP no válida o incompleta' };

  const bucket = admin.storage().bucket(object.bucket);
  const file = bucket.file(object.name);
  const [result] = await client.textDetection(file);
  const fullText = result.textAnnotations[0]?.description?.toUpperCase() || '';

  const curpMatch = fullText.includes(userCURP);
  const nameMatch = userName && fullText.includes(userName);

  const isValid = curpMatch && nameMatch;
  const reason = isValid ? 'Acta de nacimiento verificada (CURP válida)' : (!curpMatch ? 'La CURP no aparece en el acta' : 'El nombre no coincide con el acta');

  return { isValid, reason, extractedData: userCURP };
}

async function verifyConstanciaFiscal(object, userRFC) {
  if (!userRFC || userRFC.length < 12) return { isValid: false, reason: 'RFC no válido o incompleto' };

  const bucket = admin.storage().bucket(object.bucket);
  const file = bucket.file(object.name);
  const [result] = await client.textDetection(file);
  const fullText = result.textAnnotations[0]?.description?.toUpperCase() || '';

  const rfcMatch = fullText.includes(userRFC);
  const hasSATKeyword = fullText.includes('SAT') || fullText.includes('SISTEMA DE ADMINISTRACIÓN TRIBUTARIA') || fullText.includes('CONSTANCIA DE SITUACIÓN FISCAL');

  const isValid = rfcMatch && hasSATKeyword;
  const reason = isValid ? 'Constancia fiscal verificada (RFC válido)' : (!rfcMatch ? 'El RFC no aparece en la constancia' : 'No parece ser una constancia del SAT válida');

  return { isValid, reason, extractedData: userRFC };
}

async function verifyDomicilio(object) {
  const bucket = admin.storage().bucket(object.bucket);
  const file = bucket.file(object.name);
  const [result] = await client.textDetection(file);
  const fullText = result.textAnnotations[0]?.description?.toUpperCase() || '';

  const hasSufficientText = fullText.length > 100;
  const hasAddressKeywords = fullText.includes('CALLE') || fullText.includes('AVENIDA') || fullText.includes('BLVD') || fullText.includes('CP') || fullText.includes('CODIGO POSTAL');

  const isValid = hasSufficientText && hasAddressKeywords;
  const reason = isValid ? 'Comprobante de domicilio válido' : 'El documento no parece ser un comprobante de domicilio válido o es muy borroso';

  return { isValid, reason };
}

async function verifySelfie(object) {
  const bucket = admin.storage().bucket(object.bucket);
  const file = bucket.file(object.name);
  const [result] = await client.faceDetection(file);
  const faces = result.faceAnnotations;

  const hasOneFace = faces && faces.length === 1;
  const face = faces?.[0];
  const hasGoodQuality = face && face.detectionConfidence > 0.8;

  const isValid = hasOneFace && hasGoodQuality;
  const reason = isValid ? 'Selfie válido (1 rostro detectado)' : (!hasOneFace ? 'Debe haber exactamente 1 persona en la selfie' : 'La calidad de la imagen es muy baja o el rostro no es claro');

  return { isValid, reason, extractedData: `Rostros detectados: ${faces?.length || 0}` };
}

// ==========================================
// FUNCIONES AUXILIARES
// ==========================================

async function updateDocumentStatus(userId, docType, validation) {
  const docRef = db.collection('users').doc(userId);
  await docRef.update({
    [`documents.${docType}.status`]: validation.isValid ? 'approved' : 'rejected',
    [`documents.${docType}.reason`]: validation.reason,
    [`documents.${docType}.verifiedAt`]: admin.firestore.FieldValue.serverTimestamp(),
    [`documents.${docType}.extractedData`]: validation.extractedData || null,
  });
  logger.info(`📝 ${docType}: ${validation.isValid ? '✅' : '❌'} ${validation.reason}`);
}

async function checkAllDocumentsApproved(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  const documents = userDoc.data()?.documents || {};

  const requiredDocs = ['ine_front', 'acta_nacimiento', 'constancia_fiscal', 'comprobante_domicilio', 'selfie'];
  const allApproved = requiredDocs.every(docType => documents[docType]?.status === 'approved');

  if (allApproved) {
    await db.collection('users').doc(userId).update({
      verificationStatus: 'approved',
      verificationDate: admin.firestore.FieldValue.serverTimestamp(),
      canAcceptWalks: true,
    });
    await sendFullApprovalNotification(userId);
    logger.info('🎉 ¡Todos los documentos aprobados! Paseador verificado completamente.');
  }
}

// ==========================================
// 🐾 NOTIFICAR NUEVA SOLICITUD DE PASEO A LOS PASEADORES
// ==========================================
// Se dispara cada vez que un dueño crea un paseo en /walks.
// Envía una notificación push a todos los paseadores verificados.
exports.notifyNewWalkRequest = onDocumentCreated('walks/{walkId}', async (event) => {
  const walk = event.data?.data();
  if (!walk) return null;

  // Solo notificar solicitudes nuevas sin paseador asignado
  if (walk.status !== 'pending' && walk.status !== 'paid') {
    logger.info(`Paseo con status '${walk.status}', no se notifica.`);
    return null;
  }

  const ownerName = walk.ownerName || 'Un dueño';
  const petName = walk.petName || 'su mascota';
  const amount = walk.finalAmount ?? walk.amount ?? 0;

  try {
    // 1. Buscar paseadores verificados, no bloqueados, con token FCM
    const walkersSnapshot = await db.collection('users')
      .where('role', '==', 'walker')
      .where('canAcceptWalks', '==', true)
      .get();

    const tokens = [];
    const tokenOwners = {}; // token -> userId (para limpieza de tokens inválidos)

    walkersSnapshot.forEach((doc) => {
      const data = doc.data();
      if (data.isBlocked === true) return;
      if (data.fcmToken) {
        tokens.push(data.fcmToken);
        tokenOwners[data.fcmToken] = doc.id;
      }
    });

    if (tokens.length === 0) {
      logger.info('No hay paseadores con token FCM disponibles.');
      return null;
    }

    logger.info(`📣 Notificando a ${tokens.length} paseador(es) sobre el paseo ${event.params.walkId}`);

    // 2. Enviar notificación multicast
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: '🐾 ¡Nueva solicitud de paseo!',
        body: `${ownerName} solicita un paseo para ${petName} · $${amount} MXN`,
      },
      data: {
        type: 'new_walk_request',
        walkId: event.params.walkId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          sound: 'default',
        },
      },
    });

    logger.info(`✅ Enviadas: ${response.successCount}, fallidas: ${response.failureCount}`);

    // 3. Limpiar tokens inválidos/expirados para no acumular basura
    const cleanupPromises = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const code = res.error?.code || '';
        if (code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token') {
          const userId = tokenOwners[tokens[idx]];
          logger.warn(`🧹 Eliminando token inválido del usuario ${userId}`);
          cleanupPromises.push(
            db.collection('users').doc(userId).update({
              fcmToken: admin.firestore.FieldValue.delete(),
            })
          );
        }
      }
    });
    await Promise.all(cleanupPromises);

    return null;
  } catch (error) {
    logger.error('❌ Error notificando nueva solicitud de paseo:', error);
    return null;
  }
});

async function sendFullApprovalNotification(userId) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: '🎉 ¡Felicidades! Tu cuenta está verificada',
          body: 'Todos tus documentos han sido aprobados. Ya puedes comenzar a aceptar paseos.',
        },
        data: { type: 'full_verification_approved' },
      });
    }
  } catch (error) {
    logger.error('❌ Error al enviar notificación:', error);
  }
}