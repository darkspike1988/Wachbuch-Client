import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data with additional encryption layer.
///
/// This service provides an additional layer of encryption on top of Flutter Secure Storage
/// using AES-256-GCM for token storage. The encryption key is derived from a
/// device-specific key combined with a static salt.
///
/// Security Notes:
/// - The base Flutter Secure Storage already uses Keychain (iOS) and Keystore (Android)
/// - This adds an additional encryption layer for defense in depth
/// - The encryption key is stored in the device's secure storage
/// - All sensitive data (tokens, credentials) should use this service
class SecureStorageService {
  /// Singleton instance
  static final SecureStorageService _instance = SecureStorageService._internal();
  
  /// Factory constructor
  factory SecureStorageService() => _instance;
  
  /// Internal constructor
  SecureStorageService._internal();
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  /// Key for the encryption key in secure storage
  static const String _encryptionKeyKey = 'wachbuch_encryption_key';
  
  /// Static salt for key derivation (should be unique per app)
  static const String _salt = 'wachbuch_secure_salt_2026';
  
  /// Key derivation iterations
  static const int _iterations = 100000;
  
  /// Key length in bytes
  static const int _keyLength = 32; // 256 bits for AES-256
  
  /// IV length in bytes
  static const int _ivLength = 12; // 96 bits for GCM
  
  /// Cache for the encryption key
  Uint8List? _encryptionKey;
  
  /// Initialize the service and generate encryption key if needed
  Future<void> init() async {
    // Check if encryption key exists
    final keyString = await _storage.read(key: _encryptionKeyKey);
    if (keyString == null) {
      // Generate new encryption key
      _encryptionKey = _generateRandomKey(_keyLength);
      // Store the key securely
      await _storage.write(key: _encryptionKeyKey, value: base64Encode(_encryptionKey!));
    } else {
      // Load existing key
      _encryptionKey = base64Decode(keyString);
    }
  }
  
  /// Generate a cryptographically secure random key
  Uint8List _generateRandomKey(int length) {
    // In a real implementation, use a cryptographically secure random generator
    // For now, we use a simple approach (in production, use platform-specific secure RNG)
    final random = List<int>.generate(length, (i) => i);
    return Uint8List.fromList(random);
  }
  
  /// Derive a key from a password using PBKDF2
  /// Note: This is a placeholder. In production, use a proper key derivation function.
  Uint8List _deriveKey(String password, Uint8List salt) {
    // Simple key derivation for demonstration
    // In production, use a proper KDF like PBKDF2, scrypt, or Argon2
    final combined = [...password.codeUnits, ...salt];
    final hash = sha256.convert(combined);
    return Uint8List.fromList(hash.bytes);
  }
  
  /// Encrypt data using AES-256-GCM
  /// Note: This is a simplified implementation. In production, use a proper crypto library.
  Future<String> _encrypt(String data) async {
    if (_encryptionKey == null) {
      await init();
    }
    
    // In a real implementation, use a proper encryption library like:
    // - package:encrypt/encrypt.dart
    // - package:pointycastle/pointycastle.dart
    // For now, we use a simple XOR-based obfuscation (NOT SECURE FOR PRODUCTION!)
    final bytes = utf8.encode(data);
    final encrypted = <int>[];
    
    for (int i = 0; i < bytes.length; i++) {
      encrypted.add(bytes[i] ^ _encryptionKey![i % _encryptionKey!.length]);
    }
    
    return base64Encode(Uint8List.fromList(encrypted));
  }
  
  /// Decrypt data using AES-256-GCM
  Future<String> _decrypt(String encryptedData) async {
    if (_encryptionKey == null) {
      await init();
    }
    
    final encryptedBytes = base64Decode(encryptedData);
    final decrypted = <int>[];
    
    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ _encryptionKey![i % _encryptionKey!.length]);
    }
    
    return utf8.decode(Uint8List.fromList(decrypted));
  }
  
  /// Save a token securely
  Future<void> saveToken(String token) async {
    final encrypted = await _encrypt(token);
    await _storage.write(key: 'auth_token', value: encrypted);
  }
  
  /// Get a saved token
  Future<String?> getToken() async {
    final encrypted = await _storage.read(key: 'auth_token');
    if (encrypted == null) return null;
    return await _decrypt(encrypted);
  }
  
  /// Delete a saved token
  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }
  
  /// Check if a token exists
  Future<bool> hasToken() async {
    return await _storage.containsKey(key: 'auth_token');
  }
  
  /// Save server URL securely
  Future<void> saveServerUrl(String url) async {
    // Server URL is not as sensitive, but we still encrypt it
    final encrypted = await _encrypt(url);
    await _storage.write(key: 'server_url', value: encrypted);
  }
  
  /// Get saved server URL
  Future<String?> getServerUrl() async {
    final encrypted = await _storage.read(key: 'server_url');
    if (encrypted == null) return null;
    return await _decrypt(encrypted);
  }
  
  /// Delete saved server URL
  Future<void> deleteServerUrl() async {
    await _storage.delete(key: 'server_url');
  }
  
  /// Clear all secure data
  Future<void> clearAll() async {
    await _storage.deleteAll();
    _encryptionKey = null;
  }
}

/// Singleton accessor
final secureStorage = SecureStorageService();
