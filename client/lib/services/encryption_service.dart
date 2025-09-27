import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class EncryptionService extends ChangeNotifier {
  final Map<String, Uint8List> _channelKeys = {};

  final Map<String, EncryptionStatus> _channelStatus = {};

  final Map<String, Map<String, String>> _channelPublicKeys = {};

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  EncryptionStatus getChannelEncryptionStatus(String channelId) {
    return _channelStatus[channelId] ?? EncryptionStatus.disabled;
  }

  bool isChannelEncryptionReady(String channelId) {
    return _channelStatus[channelId] == EncryptionStatus.ready;
  }

  Future<void> initialize() async {
    try {
      await _loadStoredKeys();
      _isInitialized = true;
      notifyListeners();
      debugPrint('[Encryption] Service initialized');
    } catch (e) {
      debugPrint('[Encryption] Failed to initialize: $e');
    }
  }

  Future<ECDHKeyPair> generateKeyPair() async {
    try {
      final random = Random.secure();
      final privateKey = Uint8List(32);
      final publicKey = Uint8List(32);

      for (int i = 0; i < 32; i++) {
        privateKey[i] = random.nextInt(256);
        publicKey[i] = random.nextInt(256);
      }

      return ECDHKeyPair(publicKey: publicKey, privateKey: privateKey);
    } catch (e) {
      debugPrint('[Encryption] Failed to generate key pair: $e');
      rethrow;
    }
  }

  Uint8List deriveEncryptionKey(Uint8List sharedSecret, String channelId) {
    final salt = utf8.encode('operation_won_salt');
    final info = utf8.encode('operation_won_$channelId');

    final hmacExtract = Hmac(sha256, salt);
    final prk = hmacExtract.convert(sharedSecret);

    final hmacExpand = Hmac(sha256, prk.bytes);
    final expandInput = Uint8List.fromList([...info, 0x01]);
    final okm = hmacExpand.convert(expandInput);

    return Uint8List.fromList(okm.bytes);
  }

  Future<bool> setupChannelEncryption(
      String channelId, List<String> userIds) async {
    try {
      _channelStatus[channelId] = EncryptionStatus.initializing;
      notifyListeners();

      final keyPair = await generateKeyPair();

      await _storePrivateKey(channelId, keyPair.privateKey);

      _channelStatus[channelId] = EncryptionStatus.keyExchange;
      notifyListeners();

      debugPrint('[Encryption] Channel $channelId encryption setup initiated');
      return true;
    } catch (e) {
      debugPrint('[Encryption] Failed to setup channel encryption: $e');
      _channelStatus[channelId] = EncryptionStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> processKeyExchange(
      String channelId, String userId, String publicKeyBase64) async {
    try {
      if (!_channelPublicKeys.containsKey(channelId)) {
        _channelPublicKeys[channelId] = {};
      }

      _channelPublicKeys[channelId]![userId] = publicKeyBase64;

      final privateKey = await _getPrivateKey(channelId);
      if (privateKey != null) {
        await _deriveAndStoreSharedKey(
            channelId, privateKey, base64Decode(publicKeyBase64));
      }

      debugPrint(
          '[Encryption] Processed key exchange for channel $channelId from user $userId');
    } catch (e) {
      debugPrint('[Encryption] Failed to process key exchange: $e');
    }
  }

  Future<EncryptedAudioChunk?> encryptAudioChunk(
      Uint8List audioData, String channelId) async {
    if (!isChannelEncryptionReady(channelId)) {
      debugPrint('[Encryption] Channel $channelId encryption not ready');
      return null;
    }

    try {
      final key = _channelKeys[channelId];
      if (key == null) {
        debugPrint('[Encryption] No encryption key for channel $channelId');
        return null;
      }

      final nonce = generateNonce();

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        128,
        nonce,
        Uint8List(0),
      );

      cipher.init(true, params);

      final encryptedData = cipher.process(audioData);

      final authTagLength = 16;
      final ciphertext =
          encryptedData.sublist(0, encryptedData.length - authTagLength);
      final authTag =
          encryptedData.sublist(encryptedData.length - authTagLength);

      return EncryptedAudioChunk(
        encryptedData: ciphertext,
        nonce: nonce,
        authTag: authTag,
        channelId: channelId,
        sequence: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('[Encryption] Failed to encrypt audio chunk: $e');
      return null;
    }
  }

  Future<Uint8List?> decryptAudioChunk(
      EncryptedAudioChunk encryptedChunk, String channelId) async {
    if (!isChannelEncryptionReady(channelId)) {
      debugPrint(
          '[Encryption] Channel $channelId encryption not ready for decryption');
      return null;
    }

    try {
      final key = _channelKeys[channelId];
      if (key == null) {
        debugPrint('[Encryption] No decryption key for channel $channelId');
        return null;
      }

      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
        KeyParameter(key),
        128,
        encryptedChunk.nonce,
        Uint8List(0),
      );

      cipher.init(false, params);

      final combined = Uint8List.fromList([
        ...encryptedChunk.encryptedData,
        ...encryptedChunk.authTag,
      ]);

      final decryptedData = cipher.process(combined);

      return decryptedData;
    } catch (e) {
      debugPrint('[Encryption] Failed to decrypt audio chunk: $e');
      return null;
    }
  }

  Uint8List generateNonce() {
    final random = Random.secure();
    final nonce = Uint8List(12);
    for (int i = 0; i < nonce.length; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  Future<void> clearAllEncryptionData() async {
    _channelKeys.clear();
    _channelStatus.clear();
    _channelPublicKeys.clear();

    notifyListeners();
    debugPrint('[Encryption] All encryption data cleared');
  }

  Future<void> clearChannelEncryption(String channelId) async {
    _channelKeys.remove(channelId);
    _channelStatus.remove(channelId);
    _channelPublicKeys.remove(channelId);
    _storedPrivateKeys.remove(channelId); // Clear stored private key

    notifyListeners();
    debugPrint('[Encryption] Cleared encryption data for channel $channelId');
  }

  String encodePublicKey(Uint8List publicKey) {
    return base64Encode(publicKey);
  }

  Uint8List decodePublicKey(String publicKeyBase64) {
    return base64Decode(publicKeyBase64);
  }

  @visibleForTesting
  void testSetChannelKey(String channelId, Uint8List key) {
    _channelKeys[channelId] = key;
    _channelStatus[channelId] = EncryptionStatus.ready;
    notifyListeners();
  }

  Future<void> _loadStoredKeys() async {
    debugPrint('[Encryption] Loading stored keys (placeholder)');
  }

  // In-memory storage for private keys (for demo - use secure storage in production)
  final Map<String, Uint8List> _storedPrivateKeys = {};

  Future<void> _storePrivateKey(String channelId, Uint8List privateKey) async {
    final keyString = base64Encode(privateKey);

    // Store in memory for demo (in production, use secure storage)
    _storedPrivateKeys[channelId] = privateKey;

    debugPrint(
        '[Encryption] Storing private key for channel $channelId (${keyString.length} chars)');
  }

  Future<Uint8List?> _getPrivateKey(String channelId) async {
    debugPrint('[Encryption] Retrieving private key for channel $channelId');

    final privateKey = _storedPrivateKeys[channelId];
    if (privateKey != null) {
      debugPrint('[Encryption] Found private key for channel $channelId');
      return privateKey;
    }

    debugPrint('[Encryption] No private key found for channel $channelId');
    return null;
  }

  Future<void> _deriveAndStoreSharedKey(
      String channelId, Uint8List privateKey, Uint8List publicKey) async {
    final sharedSecret = Uint8List(32);

    for (int i = 0; i < 32; i++) {
      sharedSecret[i] = privateKey[i] ^ publicKey[i];
    }

    final hashedSecret = sha256.convert(sharedSecret);
    final finalSecret = Uint8List.fromList(hashedSecret.bytes);

    final encryptionKey = deriveEncryptionKey(finalSecret, channelId);
    _channelKeys[channelId] = encryptionKey;
    _channelStatus[channelId] = EncryptionStatus.ready;

    notifyListeners();
    debugPrint(
        '[Encryption] Shared key derived and stored for channel $channelId');
  }
}

class ECDHKeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;

  ECDHKeyPair({required this.publicKey, required this.privateKey});
}

class EncryptedAudioChunk {
  final Uint8List encryptedData;
  final Uint8List nonce;
  final Uint8List authTag;
  final String channelId;
  final int sequence;

  EncryptedAudioChunk({
    required this.encryptedData,
    required this.nonce,
    required this.authTag,
    required this.channelId,
    required this.sequence,
  });

  Map<String, dynamic> toJson() => {
        'encrypted_data': base64Encode(encryptedData),
        'nonce': base64Encode(nonce),
        'auth_tag': base64Encode(authTag),
        'channel_id': channelId,
        'sequence': sequence,
      };

  factory EncryptedAudioChunk.fromJson(Map<String, dynamic> json) =>
      EncryptedAudioChunk(
        encryptedData: base64Decode(json['encrypted_data']),
        nonce: base64Decode(json['nonce']),
        authTag: base64Decode(json['auth_tag']),
        channelId: json['channel_id'],
        sequence: json['sequence'],
      );
}

enum EncryptionStatus { disabled, initializing, keyExchange, ready, error }
