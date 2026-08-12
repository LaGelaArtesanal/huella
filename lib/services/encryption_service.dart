import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'aes_encryption_key_32';

  // Obtiene o genera la clave AES-256
  Future<enc.Key> _getKey() async {
    var keyStr = await _storage.read(key: _keyName);

    if (keyStr == null || keyStr.isEmpty) {
      // Genera una clave aleatoria segura de 32 bytes (256 bits)
      final randomKey = enc.Key.fromSecureRandom(32);
      keyStr = randomKey.base64;
      await _storage.write(key: _keyName, value: keyStr);
    }

    return enc.Key.fromBase64(keyStr!);
  }

  // Cifra texto plano -> Base64(iv:texto_cifrado)
  Future<String> encrypt(String plainText) async {
    if (plainText.isEmpty) return '';

    final key = await _getKey();
    // IV aleatorio para cada cifrado (evita patrones)
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Guardamos IV + Texto Cifrado juntos separados por ':'
    return '${iv.base64}:${encrypted.base64}';
  }

  // Descifra Base64(iv:texto_cifrado) -> Texto plano
  Future<String> decrypt(String encryptedData) async {
    if (encryptedData.isEmpty) return '';

    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) return encryptedData; // Si no tiene formato, retorna original

      final key = await _getKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);

      final encrypter = enc.Encrypter(enc.AES(key));
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Error al descifrar: $e');
      return encryptedData; // Retorna original si falla
    }
  }
}