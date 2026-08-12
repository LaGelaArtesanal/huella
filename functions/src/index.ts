import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as geofire from "geofire-common";
import { Request, Response } from "express";

admin.initializeApp();
const db = admin.firestore();

// ============================================================
// 1. ASIGNACIÓN AUTOMÁTICA (Segura por defecto - Trigger de Firestore)
// ============================================================
export const onWalkCreated = functions.firestore.onDocumentCreated(
  "walks/{walkId}",
  async (event: any) => {
    const snap = event.data;
    if (!snap) return;

    const walkData = snap.data();

    // Solo procesar paseos inmediatos pendientes
    if (walkData?.status !== "pending" || !walkData?.isImmediate) {
      return null;
    }

    try {
      const center: [number, number] = [
        walkData.ownerLat as number,
        walkData.ownerLng as number
      ];
      const radiusInM = 5000;
      const bounds = geofire.geohashQueryBounds(center, radiusInM);

      const promises: Promise<admin.firestore.QuerySnapshot>[] = [];
      for (const b of bounds) {
        const q = db.collection("users")
          .where("role", "==", "walker")
          .orderBy("geohash")
          .startAt(b[0])
          .endAt(b[1]);
        promises.push(q.get());
      }

      const snapshots = await Promise.all(promises);
      const matchingDocs: admin.firestore.QueryDocumentSnapshot[] = [];

      for (const s of snapshots) {
        for (const doc of s.docs) {
          const lat = doc.get("lat") as number;
          const lng = doc.get("lng") as number;
          const distanceInM = geofire.distanceBetween([lat, lng], center);

          if (distanceInM <= radiusInM) {
            matchingDocs.push(doc);
          }
        }
      }

      // Filtrar paseadores con menos de 2 paseos activos
      const eligibleWalkers = matchingDocs.filter(
        (doc) => (doc.data().activeWalks || 0) < 2
      );

      // Ordenar: primero los que tienen menos paseos, luego por rating
      eligibleWalkers.sort((a, b) => {
        const aWalks = a.data().activeWalks || 0;
        const bWalks = b.data().activeWalks || 0;
        if (aWalks !== bWalks) return aWalks - bWalks;
        return (b.data().rating || 0) - (a.data().rating || 0);
      });

      if (eligibleWalkers.length === 0) {
        console.log("No hay paseadores elegibles");
        return null;
      }

      const bestWalker = eligibleWalkers[0];
      const walkerId = bestWalker.id;

      const batch = db.batch();
      batch.update(snap.ref, {
        walkerId: walkerId,
        status: "assigned",
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.update(bestWalker.ref, {
        activeWalks: admin.firestore.FieldValue.increment(1),
      });
      await batch.commit();

      console.log(`✅ Paseo asignado a ${walkerId}`);
      return null;

    } catch (error) {
      console.error("❌ Error en asignación:", error);
      return null;
    }
  }
);

// ============================================================
// 2. MIGRACIÓN DE GEOHASH (PROTEGIDA - Solo Admins)
// ============================================================
export const migrateWalkerLocations = functions.https.onRequest(
  async (req: Request, res: Response) => {
    // ✅ VALIDACIÓN DE SEGURIDAD OBLIGATORIA
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No autorizado. Se requiere token.' });
    }

    try {
      const token = authHeader.split('Bearer ')[1];
      const decodedToken = await admin.auth().verifyIdToken(token);

      // Verificar que el usuario exista y sea administrador
      const userDoc = await db.collection('users').doc(decodedToken.uid).get();
      const userData = userDoc.data();

      if (!userData || (userData.role !== 'admin' && userData.role !== 'temp_admin')) {
        return res.status(403).json({ error: 'Permiso denegado. Solo admins pueden ejecutar esta migración.' });
      }

      // Lógica original de migración
      const walkersSnapshot = await db.collection("users")
        .where("role", "==", "walker")
        .get();

      let updatedCount = 0;
      const batch = db.batch();

      for (const doc of walkersSnapshot.docs) {
        const data = doc.data();
        // Solo actualizar si tiene coordenadas pero no geohash
        if (data.lat && data.lng && !data.geohash) {
          const hash = geofire.geohashForLocation([
            data.lat as number,
            data.lng as number
          ]);
          batch.update(doc.ref, { geohash: hash });
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        res.status(200).send(`✅ Migración completada: ${updatedCount} paseadores actualizados.`);
      } else {
        res.status(200).send("ℹ️ No se encontraron paseadores pendientes de migración.");
      }
    } catch (error) {
      console.error("❌ Error en migración:", error);
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  }
);