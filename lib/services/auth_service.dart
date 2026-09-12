import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      UserModel user = UserModel(
        uid: credential.user!.uid,
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      return user;
    } catch (e) {
      print('❌ Error al registrar: $e');
      rethrow;
    }
  }

  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = credential.user!.uid;
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        print('⚠️ El usuario existe en Auth, pero NO tiene documento en Firestore (uid: $uid)');
        await _auth.signOut();
        throw Exception('No se encontró el perfil de este usuario en la base de datos.');
      }
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Error al iniciar sesión';
      if (e.code == 'user-not-found') errorMsg = 'No existe una cuenta con este correo.';
      if (e.code == 'wrong-password') errorMsg = 'La contraseña es incorrecta.';
      if (e.code == 'invalid-email') errorMsg = 'El formato del correo no es válido.';
      if (e.code == 'user-disabled') errorMsg = 'Esta cuenta ha sido deshabilitada.';

      print('❌ Error de Auth: $errorMsg (${e.code})');
      throw Exception(errorMsg);
    } catch (e) {
      print('❌ Error inesperado en login: $e');
      throw Exception('Ocurrió un error inesperado: $e');
    }
  }

  // ✅ NUEVO: LOGIN CON GOOGLE
  Future<UserModel?> signInWithGoogle() async {
    try {
      // 1. Iniciar el flujo de Google Sign-In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        print('🚫 Usuario canceló el login con Google');
        return null;
      }

      // 2. Obtener los detalles de autenticación
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Crear una credencial de Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Iniciar sesión en Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user == null) {
        throw Exception('No se pudo obtener el usuario de Firebase');
      }

      // 5. Verificar si ya existe en Firestore, si no, crearlo
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();

      UserModel userModel;
      if (doc.exists) {
        userModel = UserModel.fromMap(doc.data() as Map<String, dynamic>);
      } else {
        // Usuario nuevo: crear documento en Firestore con rol 'owner' por defecto
        userModel = UserModel(
          uid: user.uid,
          email: user.email ?? googleUser.email,
          name: user.displayName ?? googleUser.displayName ?? 'Usuario de Google',
          role: 'owner',
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(userModel.toMap());
        print('✅ Nuevo usuario de Google creado en Firestore');
      }

      print('✅ Login con Google exitoso: ${userModel.name}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      print('❌ Error de Auth con Google: ${e.code} - ${e.message}');
      throw Exception('Error al iniciar sesión con Google: ${e.message}');
    } catch (e) {
      print('❌ Error inesperado con Google: $e');
      throw Exception('Error al iniciar sesión con Google: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}