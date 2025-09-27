import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:operation_won/services/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService AES-256-GCM Tests', () {
    late EncryptionService encryptionService;
    const String testChannelId = 'test-channel-123';

    setUp(() {
      encryptionService = EncryptionService();
    });

    tearDown(() {
      encryptionService.dispose();
    });

    test('should initialize correctly', () async {
      await encryptionService.initialize();
      expect(encryptionService.isInitialized, true);
    });

    test('should generate secure key pairs', () async {
      final keyPair = await encryptionService.generateKeyPair();

      expect(keyPair.publicKey.length, 32); // 32 bytes for demo keys
      expect(keyPair.privateKey.length, 32);

      // Keys should be different
      expect(keyPair.publicKey, isNot(equals(keyPair.privateKey)));
    });

    test('should encrypt and decrypt audio data with AES-256-GCM', () async {
      await encryptionService.initialize();

      // Setup channel encryption (simulate successful key exchange)
      await encryptionService.setupChannelEncryption(testChannelId, []);

      // Manually set a test key to simulate successful key exchange
      final testKey = Uint8List(32);
      for (int i = 0; i < testKey.length; i++) {
        testKey[i] = i % 256;
      }

      // Access private method through reflection for testing
      // In production, this would happen through proper key exchange
      encryptionService.testSetChannelKey(testChannelId, testKey);

      // Create test audio data (simulate Opus-encoded audio)
      final testAudioData = Uint8List.fromList([
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0A,
        0x0B,
        0x0C,
        0x0D,
        0x0E,
        0x0F,
        0x10,
        0x11,
        0x12,
        0x13,
        0x14,
        0x15,
        0x16,
        0x17,
        0x18,
        0x19,
        0x1A,
        0x1B,
        0x1C,
        0x1D,
        0x1E,
        0x1F,
        0x20,
      ]);

      // Encrypt the audio data
      final encryptedChunk = await encryptionService.encryptAudioChunk(
          testAudioData, testChannelId);

      expect(encryptedChunk, isNotNull);
      expect(encryptedChunk!.encryptedData.length, testAudioData.length);
      expect(encryptedChunk.nonce.length, 12); // GCM nonce is 12 bytes
      expect(encryptedChunk.authTag.length, 16); // GCM auth tag is 16 bytes
      expect(encryptedChunk.channelId, testChannelId);

      // Encrypted data should be different from original
      expect(encryptedChunk.encryptedData, isNot(equals(testAudioData)));

      // Decrypt the audio data
      final decryptedData = await encryptionService.decryptAudioChunk(
          encryptedChunk, testChannelId);

      expect(decryptedData, isNotNull);
      expect(decryptedData, equals(testAudioData));
    });

    test('should handle encryption status correctly', () async {
      await encryptionService.initialize();

      // Initially disabled
      expect(encryptionService.getChannelEncryptionStatus(testChannelId),
          EncryptionStatus.disabled);
      expect(encryptionService.isChannelEncryptionReady(testChannelId), false);

      // Setup channel encryption
      await encryptionService.setupChannelEncryption(testChannelId, []);

      // Should be in key exchange state
      expect(encryptionService.getChannelEncryptionStatus(testChannelId),
          EncryptionStatus.keyExchange);
      expect(encryptionService.isChannelEncryptionReady(testChannelId), false);
    });

    test('should encode and decode public keys', () {
      final testKey = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final encoded = encryptionService.encodePublicKey(testKey);
      final decoded = encryptionService.decodePublicKey(encoded);

      expect(decoded, equals(testKey));
      expect(encoded, isA<String>());
      expect(encoded.isNotEmpty, true);
    });

    test('should generate different nonces each time', () {
      final nonce1 = encryptionService.generateNonce();
      final nonce2 = encryptionService.generateNonce();

      expect(nonce1.length, 12);
      expect(nonce2.length, 12);
      expect(nonce1, isNot(equals(nonce2)));
    });

    test('should clear channel encryption data', () async {
      await encryptionService.initialize();
      await encryptionService.setupChannelEncryption(testChannelId, []);

      expect(encryptionService.getChannelEncryptionStatus(testChannelId),
          isNot(EncryptionStatus.disabled));

      await encryptionService.clearChannelEncryption(testChannelId);

      expect(encryptionService.getChannelEncryptionStatus(testChannelId),
          EncryptionStatus.disabled);
    });
  });
}
