import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pet_model.dart';

class PetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Agregar nueva mascota
  Future<PetModel?> addPet(PetModel pet) async {
    try {
      DocumentReference docRef = await _firestore.collection('pets').add(pet.toMap());

      // Actualizar el ID con el generado por Firestore
      PetModel petWithId = PetModel(
        id: docRef.id,
        ownerId: pet.ownerId,
        name: pet.name,
        breed: pet.breed,
        size: pet.size,
        age: pet.age,
        photoUrl: pet.photoUrl,
        createdAt: pet.createdAt,
      );

      await docRef.update({'id': docRef.id});

      return petWithId;
    } catch (e) {
      print('Error al agregar mascota: $e');
      return null;
    }
  }

  // Obtener mascotas de un dueño
  Stream<List<PetModel>> getPetsByOwner(String ownerId) {
    return _firestore
        .collection('pets')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      return PetModel.fromMap(doc.data(), doc.id);
    }).toList());
  }

  // Eliminar mascota
  Future<void> deletePet(String petId) async {
    try {
      await _firestore.collection('pets').doc(petId).delete();
    } catch (e) {
      print('Error al eliminar mascota: $e');
    }
  }
}