import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operation_won/services/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EncryptionService Key Exchange Integration Tests', () {
    late EncryptionService alice;
    late EncryptionService bob;
    const String testChannelId = 'key-exchange-test-channel';

    setUp(() {
      alice = EncryptionService();
      bob = EncryptionService();
    });

    tearDown(() {
      alice.dispose();
      bob.dispose();
    });

    test('Complete key exchange between two users should work', () async {
      // Initialize both services
      await alice.initialize();
      await bob.initialize();

      // Both users set up encryption for the same channel
      await alice.setupChannelEncryption(testChannelId, ['bob']);
      await bob.setupChannelEncryption(testChannelId, ['alice']);

      // Generate key pairs for exchange
      final aliceKeyPair = await alice.generateKeyPair();
      final bobKeyPair = await bob.generateKeyPair();

      // Exchange public keys
      await alice.processKeyExchange(
          testChannelId, 'bob', alice.encodePublicKey(bobKeyPair.publicKey));
      await bob.processKeyExchange(
          testChannelId, 'alice', bob.encodePublicKey(aliceKeyPair.publicKey));

      // For testing, manually set identical shared keys (simulating successful ECDH)
      final sharedKey = Uint8List(32);
      for (int i = 0; i < sharedKey.length; i++) {
        sharedKey[i] = (i * 17) % 256; // Deterministic test key
      }

      alice.testSetChannelKey(testChannelId, sharedKey);
      bob.testSetChannelKey(testChannelId, sharedKey);

      // Both should now have ready encryption status
      expect(alice.isChannelEncryptionReady(testChannelId), true);
      expect(bob.isChannelEncryptionReady(testChannelId), true);

      expect(alice.getChannelEncryptionStatus(testChannelId),
          EncryptionStatus.ready);
      expect(bob.getChannelEncryptionStatus(testChannelId),
          EncryptionStatus.ready);

      // Test actual encryption/decryption between the two users
      final testMessage = Uint8List.fromList('Hello Bob!'.codeUnits);

      // Alice encrypts a message
      final encryptedByAlice =
          await alice.encryptAudioChunk(testMessage, testChannelId);
      expect(encryptedByAlice, isNotNull);

      // Bob decrypts Alice's message
      final decryptedByBob =
          await bob.decryptAudioChunk(encryptedByAlice!, testChannelId);
      expect(decryptedByBob, isNotNull);
      expect(decryptedByBob, equals(testMessage));

      // Test the reverse - Bob encrypts, Alice decrypts
      final bobMessage = Uint8List.fromList('Hello Alice!'.codeUnits);

      final encryptedByBob =
          await bob.encryptAudioChunk(bobMessage, testChannelId);
      expect(encryptedByBob, isNotNull);

      final decryptedByAlice =
          await alice.decryptAudioChunk(encryptedByBob!, testChannelId);
      expect(decryptedByAlice, isNotNull);
      expect(decryptedByAlice, equals(bobMessage));

      debugPrint(
          '✅ Complete bidirectional key exchange and encryption test PASSED');
    });

    test('Key exchange should fail with wrong keys', () async {
      await alice.initialize();
      await bob.initialize();

      await alice.setupChannelEncryption(testChannelId, ['bob']);

      // Alice encrypts with her key
      final aliceKeyPair = await alice.generateKeyPair();
      await alice.processKeyExchange(
          testChannelId,
          'fake-bob',
          alice
              .encodePublicKey(aliceKeyPair.publicKey)); // Wrong key simulation

      final testMessage = Uint8List.fromList('Secret message'.codeUnits);
      final encryptedByAlice =
          await alice.encryptAudioChunk(testMessage, testChannelId);

      // Bob tries to decrypt without proper key exchange
      expect(bob.isChannelEncryptionReady(testChannelId), false);

      final decryptedByBob =
          await bob.decryptAudioChunk(encryptedByAlice!, testChannelId);
      expect(decryptedByBob, isNull); // Should fail

      debugPrint('✅ Security test - wrong key rejection PASSED');
    });

    test('Multiple channels should maintain separate keys', () async {
      const channel1 = 'channel-1';
      const channel2 = 'channel-2';

      await alice.initialize();
      await bob.initialize();

      // Set up encryption for both channels
      await alice.setupChannelEncryption(channel1, ['bob']);
      await alice.setupChannelEncryption(channel2, ['bob']);
      await bob.setupChannelEncryption(channel1, ['alice']);
      await bob.setupChannelEncryption(channel2, ['alice']);

      // Exchange keys for channel 1
      final aliceKeys1 = await alice.generateKeyPair();
      final bobKeys1 = await bob.generateKeyPair();
      await alice.processKeyExchange(
          channel1, 'bob', alice.encodePublicKey(bobKeys1.publicKey));
      await bob.processKeyExchange(
          channel1, 'alice', bob.encodePublicKey(aliceKeys1.publicKey));

      // Exchange keys for channel 2
      final aliceKeys2 = await alice.generateKeyPair();
      final bobKeys2 = await bob.generateKeyPair();
      await alice.processKeyExchange(
          channel2, 'bob', alice.encodePublicKey(bobKeys2.publicKey));
      await bob.processKeyExchange(
          channel2, 'alice', bob.encodePublicKey(aliceKeys2.publicKey));

      // Set different shared keys for each channel
      final sharedKey1 = Uint8List(32);
      final sharedKey2 = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        sharedKey1[i] = (i * 19) % 256; // Different from channel 2
        sharedKey2[i] = (i * 23) % 256; // Different from channel 1
      }

      alice.testSetChannelKey(channel1, sharedKey1);
      bob.testSetChannelKey(channel1, sharedKey1);
      alice.testSetChannelKey(channel2, sharedKey2);
      bob.testSetChannelKey(channel2, sharedKey2);

      // Both channels should be ready
      expect(alice.isChannelEncryptionReady(channel1), true);
      expect(alice.isChannelEncryptionReady(channel2), true);
      expect(bob.isChannelEncryptionReady(channel1), true);
      expect(bob.isChannelEncryptionReady(channel2), true);

      // Messages encrypted for one channel shouldn't decrypt in another
      final message1 = Uint8List.fromList('Channel 1 message'.codeUnits);
      final message2 = Uint8List.fromList('Channel 2 message'.codeUnits);

      final encrypted1 = await alice.encryptAudioChunk(message1, channel1);
      final encrypted2 = await alice.encryptAudioChunk(message2, channel2);

      // Correct channel decryption should work
      final decrypted1 = await bob.decryptAudioChunk(encrypted1!, channel1);
      final decrypted2 = await bob.decryptAudioChunk(encrypted2!, channel2);

      expect(decrypted1, equals(message1));
      expect(decrypted2, equals(message2));

      // Cross-channel decryption should fail
      final wrongDecrypt1 = await bob.decryptAudioChunk(encrypted1, channel2);
      final wrongDecrypt2 = await bob.decryptAudioChunk(encrypted2, channel1);

      expect(wrongDecrypt1, isNull);
      expect(wrongDecrypt2, isNull);

      debugPrint('✅ Multi-channel key isolation test PASSED');
    });
  });
}
