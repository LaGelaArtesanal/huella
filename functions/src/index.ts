import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as vision from "@google-cloud/vision";
import Stripe from "stripe"; // ✅ Importación por defecto correcta

admin.initializeApp();
const db = admin.firestore();
const visionClient = new vision.ImageAnnotatorClient();

// ✅ INICIALIZAR STRIPE
// La clave secreta debe provenir de un secret de Firebase (NUNCA hardcodeada en el repo):
//   firebase functions:secrets:set STRIPE_SECRET_KEY
// Se deja como fallback la clave de prueba anterior para desarrollo local.
const stripeSecretKey =
  process.env.STRIPE_SECRET_KEY ??
  "sk_test_51UAHSHHweWHZEXEPN6PvcV9L1Zixnj9ffltq5zzhbadi6mNlrhGhKd691Kx3ZaLqkqH1wWVPDlVyYrrGacw0yeAT00LOBeVhfS";

// ✅ CORREGIDO: Se eliminó apiVersion para evitar conflictos de tipos con la versión nueva del paquete
const stripe = new Stripe(stripeSecretKey);

if (!process.env.STRIPE_SECRET_KEY) {
  console.warn(
    "⚠️ STRIPE_SECRET_KEY no está configurada: usando la clave de prueba embebida. " +
      "Configúrala con: firebase functions:secrets:set STRIPE_SECRET_KEY"
  );
}

// ==========================================
// 1. NOTIFICACIÓN DE CHAT
// ==========================================
export const sendChatNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data?.data();
    const chatId = event.params.chatId;

    logger.info(`🔔 Nuevo mensaje en chat: ${chatId}`);

    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      logger.error("❌ Chat no encontrado");
      return;
    }

    const chatData = chatDoc.data();
    const senderId = messageData?.senderId;
    const participant1Id = chatData?.participant1Id;
    const participant2Id = chatData?.participant2Id;

    let receiverId: string | null = null;
    if (senderId === participant1Id) {
      receiverId = participant2Id;
    } else if (senderId === participant2Id) {
      receiverId = participant1Id;
    }

    if (!receiverId) {
      logger.error(`❌ No se pudo determinar el receptor. Sender: ${senderId}`);
      return;
    }

    const userDoc = await db.collection("users").doc(receiverId).get();
    if (!userDoc.exists || !userDoc.data()?.fcmToken) {
      logger.info(`❌ El usuario ${receiverId} no tiene token FCM`);
      return;
    }

    const fcmToken = userDoc.data()!.fcmToken;

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: "Nuevo mensaje de Huella 🐾",
        body: messageData?.text || "Tienes un nuevo mensaje",
      },
      data: {
        type: "chat",
        chatId: chatId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "chat_message_channel",
          sound: "default",
        },
      },
    };

    try {
      await admin.messaging().send(message);
      logger.info(`✅ Notificación de chat enviada a: ${receiverId}`);
    } catch (error) {
      logger.error("❌ Error enviando notificación:", error);
    }
  }
);

// ==========================================
// 2. NOTIFICACIÓN DE NUEVO PASEO + REGISTRO DE HEATMAP
// ==========================================
export const sendWalkRequestNotification = onDocumentCreated(
  "walks/{walkId}",
  async (event) => {
    const walkData = event.data?.data();

    if (walkData?.status === 'pending' || walkData?.status === 'paid') {

      const ownerLat = walkData.ownerLat;
      const ownerLng = walkData.ownerLng;

      if (ownerLat !== undefined && ownerLng !== undefined && typeof ownerLat === 'number' && typeof ownerLng === 'number') {
        await db.collection('walk_requests_heatmap').add({
          lat: ownerLat,
          lng: ownerLng,
          walkId: event.params.walkId,
          status: walkData.status,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 2 * 60 * 60 * 1000)
          ),
        });
        logger.info(`📍 Coordenadas registradas para heatmap: Lat ${ownerLat}, Lng ${ownerLng}`);
      } else {
        logger.warn(`⚠️ Coordenadas inválidas o faltantes para el paseo ${event.params.walkId}`);
      }

      const walkersSnapshot = await db.collection("users")
        .where("role", "==", "walker")
        .where("isVerified", "==", true)
        .get();

      const tokens: string[] = [];
      walkersSnapshot.forEach((doc) => {
        const data = doc.data();
        if (data.fcmToken) {
          tokens.push(data.fcmToken);
        }
      });

      if (tokens.length > 0) {
        const messages: admin.messaging.Message[] = tokens.map((token) => ({
          token: token,
          notification: {
            title: "¡Nueva Solicitud de Paseo! 🐾",
            body: "Tienes un nuevo paseo disponible. ¡Tócalo para aceptar!",
          },
          data: {
            type: "new_walk",
            walkId: event.params.walkId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              sound: "default",
            },
          },
        }));

        try {
          const response = await admin.messaging().sendEach(messages);
          logger.info(`✅ Notificación de paseo enviada: ${response.successCount} exitosas, ${response.failureCount} fallidas`);
        } catch (error) {
          logger.error("❌ Error enviando notificación de paseo:", error);
        }
      }
    }
  }
);

// ==========================================
// 3. NOTIFICACIÓN DE LLAMADA ENTRANTE
// ==========================================
export const sendCallNotification = onDocumentCreated(
  "calls/{callId}",
  async (event) => {
    const callData = event.data?.data();
    const receiverId = callData?.receiverId;

    logger.info('📞 Nueva llamada:', {
      callId: event.params.callId,
      receiverId: receiverId,
      callerId: callData?.callerId,
      callerName: callData?.callerName
    });

    if (!receiverId) {
      logger.error('❌ No hay receiverId en el documento de la llamada');
      return;
    }

    const userDoc = await db.collection("users").doc(receiverId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
      logger.info("❌ No hay token FCM para el usuario", receiverId);
      return;
    }

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: `📞 ${callData.callerName || 'Llamada entrante'}`,
        body: callData.isVideo ? 'Videollamada entrante' : 'Llamada de audio entrante',
      },
      data: {
        type: "incoming_call",
        callId: event.params.callId,
        walkId: callData.walkId || '',
        callerId: callData.callerId || '',
        callerName: callData.callerName || '',
        isVideo: callData.isVideo?.toString() || 'false',
      },
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            contentAvailable: true,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      logger.info("✅ Notificación de llamada enviada a", receiverId);
    } catch (error) {
      logger.error("❌ Error enviando notificación:", error);
    }
  }
);

// ==========================================
// 4. VERIFICACIÓN AUTOMÁTICA DE DOCUMENTOS (IA)
// ==========================================
export const verifyWalkerDocuments = onObjectFinalized(
  async (event) => {
    const object = event.data;
    if (!object) return;

    const filePath = object.name;
    const contentType = object.contentType;

    const isImage = contentType?.startsWith("image/");
    const isPDF = contentType === "application/pdf";

    if (!isImage && !isPDF) {
      logger.info("No es una imagen ni PDF, ignorando...");
      return;
    }

    if (!filePath.startsWith("walker_documents/") && !filePath.startsWith("verifications/")) {
      logger.info("No está en carpeta válida, ignorando...");
      return;
    }

    logger.info(`🔍 Procesando: ${filePath}`);

    const pathParts = filePath.split("/");
    const userId = pathParts[1];
    const fileName = pathParts[2] ? pathParts[2].split(".")[0] : "unknown";

    if (!userId || fileName === "unknown") {
      logger.error("❌ No se pudo extraer userId o fileName");
      return;
    }

    const docTypeMap: { [key: string]: string } = {
      "ine_front": "ine_front",
      "ine_back": "ine_back",
      "id": "ine_front",
      "birth_cert": "acta_nacimiento",
      "fiscal_const": "constancia_fiscal",
      "address_proof": "comprobante_domicilio",
      "selfie": "selfie",
      "acta_nacimiento": "acta_nacimiento",
      "constancia_fiscal": "constancia_fiscal",
      "comprobante_domicilio": "comprobante_domicilio",
    };

    const docType = docTypeMap[fileName] || fileName;

    try {
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        logger.error("Usuario no encontrado en Firestore");
        return;
      }

      const userData = userDoc.data();
      const userName = (userData?.name || "").toUpperCase();
      const userLastName = (userData?.lastName || "").toUpperCase();
      const userCURP = (userData?.curp || "").toUpperCase();
      const userRFC = (userData?.rfc || "").toUpperCase();

      let validationResult: any = {};

      switch (docType) {
        case "ine_front":
        case "ine_back":
          validationResult = await verifyINE(object, userName, userLastName);
          break;
        case "acta_nacimiento":
          validationResult = await verifyActaNacimiento(object, userCURP, userName);
          break;
        case "constancia_fiscal":
          validationResult = await verifyConstanciaFiscal(object, userRFC, isPDF);
          break;
        case "comprobante_domicilio":
          validationResult = await verifyDomicilio(object);
          break;
        case "selfie":
          validationResult = await verifySelfie(object);
          break;
        default:
          logger.info(`📄 Tipo de documento desconocido: ${docType}`);
          return;
      }

      await updateDocumentStatus(userId, docType, validationResult);
      await checkAllDocumentsApproved(userId);
    } catch (error) {
      logger.error("❌ Error en verificación:", error);
    }
  }
);

// ==========================================
// 5. LIMPIEZA AUTOMÁTICA DEL HEATMAP (Cada 30 minutos)
// ==========================================
export const cleanupHeatmapData = onSchedule({ schedule: "every 30 minutes" }, async () => {
  const now = admin.firestore.Timestamp.now();

  const expiredDocs = await db.collection('walk_requests_heatmap')
    .where('expiresAt', '<', now)
    .get();

  if (expiredDocs.empty) {
    logger.info("🧹 No hay registros antiguos del heatmap para limpiar");
    return;
  }

  const batch = db.batch();
  expiredDocs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  logger.info(`🧹 Limpiados ${expiredDocs.size} registros antiguos del heatmap`);
});

// ==========================================
// 6. CREAR INTENTO DE PAGO CON STRIPE (NUEVO)
// ==========================================
export const createPaymentIntent = onCall(
  { enforceAppCheck: false }, // ✅ AGREGADO: Desactiva App Check para esta función en desarrollo
  async (request) => {
    // 1. Verificar que el usuario esté autenticado
    if (!request.auth) {
      throw new Error("No autenticado");
    }

    const { amount, currency, walkId } = request.data;

    if (!amount || !currency || !walkId) {
      throw new Error("Faltan parámetros requeridos (amount, currency, walkId)");
    }

    try {
      // 2. Crear el PaymentIntent en Stripe
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100), // Stripe maneja los montos en centavos
        currency: currency, // "mxn"
        metadata: {
          walkId: walkId,
          ownerId: request.auth.uid,
        },
        automatic_payment_methods: {
          enabled: true,
        },
      });

      logger.info(`✅ PaymentIntent creado: ${paymentIntent.id} por $${amount} ${currency}`);

      // 3. Devolver el clientSecret a la app de Flutter
      return {
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      };
    } catch (error: any) {
      logger.error("❌ Error creando PaymentIntent:", error);
      throw new Error(error.message || "Error al crear el intento de pago");
    }
  }
);

// ==========================================
// FUNCIONES DE VALIDACIÓN INDIVIDUAL
// ==========================================

async function verifyINE(object: any, userName: string, userLastName: string) {
  const imageUri = `gs://${object.bucket}/${object.name}`;
  const request = { image: { source: { imageUri } } };
  const [result] = await visionClient.textDetection(request);
  const fullText = result.textAnnotations?.[0]?.description?.toUpperCase() || "";

  const nameMatch = userName && fullText.includes(userName);
  const hasINEKeyword = fullText.includes("INE") || fullText.includes("INSTITUTO NACIONAL ELECTORAL") || fullText.includes("CREDENCIAL PARA VOTAR");

  const isValid = nameMatch && hasINEKeyword;
  const reason = isValid ? "INE verificada correctamente" : (!nameMatch ? "El nombre no coincide con el registrado" : "No parece ser una credencial INE válida");

  return { isValid, reason, extractedData: fullText.substring(0, 200) };
}

async function verifyActaNacimiento(object: any, userCURP: string, userName: string) {
  if (!userCURP || userCURP.length !== 18) return { isValid: false, reason: "CURP no válida o incompleta" };

  const imageUri = `gs://${object.bucket}/${object.name}`;
  const request = { image: { source: { imageUri } } };
  const [result] = await visionClient.textDetection(request);
  const fullText = result.textAnnotations?.[0]?.description?.toUpperCase() || "";

  const curpMatch = fullText.includes(userCURP);
  const nameMatch = userName && fullText.includes(userName);

  const isValid = curpMatch && nameMatch;
  const reason = isValid ? "Acta de nacimiento verificada (CURP válida)" : (!curpMatch ? "La CURP no aparece en el acta" : "El nombre no coincide con el acta");

  return { isValid, reason, extractedData: userCURP };
}

async function verifyConstanciaFiscal(object: any, userRFC: string, isPDF: boolean = false) {
  if (!userRFC || userRFC.length < 12) return { isValid: false, reason: "RFC no válido o incompleto" };

  const imageUri = `gs://${object.bucket}/${object.name}`;
  let fullText = "";

  try {
    if (isPDF) {
      const [result] = await visionClient.documentTextDetection({ image: { source: { imageUri } } });
      fullText = result.fullTextAnnotation?.text?.toUpperCase() || "";
    } else {
      const [result] = await visionClient.textDetection({ image: { source: { imageUri } } });
      fullText = result.textAnnotations?.[0]?.description?.toUpperCase() || "";
    }
  } catch (error) {
    logger.error("Error al procesar PDF/Imagen:", error);
    return { isValid: false, reason: "Error al procesar el documento" };
  }

  const rfcMatch = fullText.includes(userRFC);
  const hasSATKeyword = fullText.includes("SAT") || fullText.includes("SISTEMA DE ADMINISTRACIÓN TRIBUTARIA") || fullText.includes("CONSTANCIA DE SITUACIÓN FISCAL");

  const isValid = rfcMatch && hasSATKeyword;
  const reason = isValid ? "Constancia fiscal verificada (RFC válido)" : (!rfcMatch ? "El RFC no aparece en la constancia" : "No parece ser una constancia del SAT válida");

  return { isValid, reason, extractedData: userRFC };
}

async function verifyDomicilio(object: any) {
  const imageUri = `gs://${object.bucket}/${object.name}`;
  const request = { image: { source: { imageUri } } };
  const [result] = await visionClient.textDetection(request);
  const fullText = result.textAnnotations?.[0]?.description?.toUpperCase() || "";

  const hasSufficientText = fullText.length > 100;
  const hasAddressKeywords = fullText.includes("CALLE") || fullText.includes("AVENIDA") || fullText.includes("BLVD") || fullText.includes("CP") || fullText.includes("CODIGO POSTAL");

  const isValid = hasSufficientText && hasAddressKeywords;
  const reason = isValid ? "Comprobante de domicilio válido" : "El documento no parece ser un comprobante de domicilio válido o es muy borroso";

  return { isValid, reason };
}

async function verifySelfie(object: any) {
  const imageUri = `gs://${object.bucket}/${object.name}`;
  const request = { image: { source: { imageUri } } };
  const [result] = await visionClient.faceDetection(request);
  const faces = result.faceAnnotations;

  const hasOneFace = faces && faces.length === 1;
  const face = faces?.[0];
  const hasGoodQuality = face && (face.detectionConfidence ?? 0) > 0.8;

  const isValid = hasOneFace && hasGoodQuality;
  const reason = isValid ? "Selfie válido (1 rostro detectado)" : (!hasOneFace ? "Debe haber exactamente 1 persona en la selfie" : "La calidad de la imagen es muy baja o el rostro no es claro");

  return { isValid, reason, extractedData: `Rostros detectados: ${faces?.length || 0}` };
}

// ==========================================
// FUNCIONES AUXILIARES
// ==========================================

async function updateDocumentStatus(userId: string, docType: string, validation: any) {
  const docRef = db.collection("users").doc(userId);
  await docRef.update({
    [`documents.${docType}.status`]: validation.isValid ? "approved" : "rejected",
    [`documents.${docType}.reason`]: validation.reason,
    [`documents.${docType}.verifiedAt`]: admin.firestore.FieldValue.serverTimestamp(),
    [`documents.${docType}.extractedData`]: validation.extractedData || null,
  });
  logger.info(`📝 ${docType}: ${validation.isValid ? "✅" : "❌"} ${validation.reason}`);
}

async function checkAllDocumentsApproved(userId: string) {
  const userDoc = await db.collection("users").doc(userId).get();
  const documents = userDoc.data()?.documents || {};

  const requiredDocs = ["ine_front", "acta_nacimiento", "constancia_fiscal", "comprobante_domicilio", "selfie"];
  const allApproved = requiredDocs.every((docType) => documents[docType]?.status === "approved");

  if (allApproved) {
    await db.collection("users").doc(userId).update({
      verificationStatus: "approved",
      verificationDate: admin.firestore.FieldValue.serverTimestamp(),
      canAcceptWalks: true,
    });
    await sendFullApprovalNotification(userId);
    logger.info("🎉 ¡Todos los documentos aprobados! Paseador verificado completamente.");
  }
}

async function sendFullApprovalNotification(userId: string) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "🎉 ¡Felicidades! Tu cuenta está verificada",
          body: "Todos tus documentos han sido aprobados. Ya puedes comenzar a aceptar paseos.",
        },
        data: { type: "full_verification_approved" },
      });
      logger.info("✅ Notificación de aprobación completa enviada");
    }
  } catch (error) {
    logger.error("❌ Error al enviar notificación:", error);
  }
}