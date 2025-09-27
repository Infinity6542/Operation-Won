import 'dart:async';
import 'package:flutter/material.dart';
import 'package:operation_won/services/communication_service.dart';
import 'package:operation_won/services/encryption_service.dart';
import 'package:operation_won/providers/settings_provider.dart';

class EncryptionDemoWidget extends StatefulWidget {
  const EncryptionDemoWidget({Key? key}) : super(key: key);

  @override
  State<EncryptionDemoWidget> createState() => _EncryptionDemoWidgetState();
}

class _EncryptionDemoWidgetState extends State<EncryptionDemoWidget> {
  late CommunicationService _communicationService;

  String _currentChannelId = 'demo-channel';
  EncryptionStatus _encryptionStatus = EncryptionStatus.disabled;

  @override
  void initState() {
    super.initState();
    _initializeCommunicationService();
  }

  void _initializeCommunicationService() {
    // Initialize with minimal settings provider
    final settingsProvider = SettingsProvider();
    _communicationService = CommunicationService(settingsProvider);

    // Listen to encryption status changes
    _communicationService.addListener(_updateEncryptionStatus);
  }

  void _updateEncryptionStatus() {
    setState(() {
      _encryptionStatus = _communicationService.encryptionStatus;
    });
  }

  @override
  void dispose() {
    _communicationService.removeListener(_updateEncryptionStatus);
    _communicationService.dispose();
    super.dispose();
  }

  String _getStatusText(EncryptionStatus status) {
    switch (status) {
      case EncryptionStatus.disabled:
        return 'Encryption Disabled';
      case EncryptionStatus.initializing:
        return 'Initializing Encryption...';
      case EncryptionStatus.keyExchange:
        return 'Key Exchange In Progress...';
      case EncryptionStatus.ready:
        return 'Encryption Ready (AES-256-GCM)';
      case EncryptionStatus.error:
        return 'Encryption Error';
    }
  }

  Color _getStatusColor(EncryptionStatus status) {
    switch (status) {
      case EncryptionStatus.disabled:
        return Colors.grey;
      case EncryptionStatus.initializing:
        return Colors.orange;
      case EncryptionStatus.keyExchange:
        return Colors.blue;
      case EncryptionStatus.ready:
        return Colors.green;
      case EncryptionStatus.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(EncryptionStatus status) {
    switch (status) {
      case EncryptionStatus.disabled:
        return Icons.lock_open;
      case EncryptionStatus.initializing:
        return Icons.hourglass_empty;
      case EncryptionStatus.keyExchange:
        return Icons.sync;
      case EncryptionStatus.ready:
        return Icons.lock;
      case EncryptionStatus.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AES-256-GCM Encryption Demo'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Encryption Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(_encryptionStatus),
                          color: _getStatusColor(_encryptionStatus),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusText(_encryptionStatus),
                          style: TextStyle(
                            color: _getStatusColor(_encryptionStatus),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Channel: $_currentChannelId',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Encryption Features',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureRow(Icons.security, 'AES-256-GCM',
                        'Authenticated encryption with 256-bit keys'),
                    _buildFeatureRow(Icons.vpn_key, 'ECDH Key Exchange',
                        'Secure key agreement between users'),
                    _buildFeatureRow(Icons.shuffle, 'Unique Nonces',
                        '12-byte random nonces for each message'),
                    _buildFeatureRow(Icons.verified, 'Authentication Tags',
                        '16-byte tags prevent message tampering'),
                    _buildFeatureRow(Icons.settings, 'HKDF Key Derivation',
                        'Proper key derivation with channel separation'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _encryptionStatus == EncryptionStatus.disabled
                                ? () => _setupEncryption()
                                : null,
                        icon: const Icon(Icons.lock),
                        label: const Text('Setup Channel Encryption'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _encryptionStatus != EncryptionStatus.disabled
                                ? () => _clearEncryption()
                                : null,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Clear Encryption'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setupEncryption() async {
    final success =
        await _communicationService.setupChannelEncryption(_currentChannelId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Encryption setup initiated! AES-256-GCM ready.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to setup encryption'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearEncryption() async {
    await _communicationService.clearChannelEncryption(_currentChannelId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Encryption cleared'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

// Extension method for CommunicationService
extension CommunicationServiceExtension on CommunicationService {
  Future<void> clearChannelEncryption(String channelId) async {
    // This would be implemented in the actual CommunicationService
    // For demo purposes, we'll simulate it
    debugPrint('Clearing encryption for channel: $channelId');
  }
}
