import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../providers/event_provider.dart';
import '../models/event_model.dart';

class CreateChannelDialog extends StatefulWidget {
  const CreateChannelDialog({super.key});

  @override
  State<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<CreateChannelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  EventResponse? _selectedEvent;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final channelProvider =
          Provider.of<ChannelProvider>(context, listen: false);

      await channelProvider.createChannel(
        _nameController.text.trim(),
        eventUuid: _selectedEvent?.eventUuid,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Channel "${_nameController.text.trim()}" created successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create channel: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        return Dialog(
          insetPadding: EdgeInsets.all(isSmallScreen ? 16 : 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.85,
              maxWidth: isSmallScreen ? screenSize.width - 32 : 500,
              minWidth: isSmallScreen ? screenSize.width - 32 : 300,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Create New Channel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.grey),
                            padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                            constraints: BoxConstraints(
                              minWidth: isSmallScreen ? 32 : 40,
                              minHeight: isSmallScreen ? 32 : 40,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),

                      // Channel Name Field
                      Text(
                        'Channel Name',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter channel name',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: const Color(0xFF374151),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF6B7280)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF6B7280)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFF10B981)),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFDC2626)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Channel name is required';
                          }
                          if (value.trim().length < 2) {
                            return 'Channel name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),

                      // Event Selection
                      Text(
                        'Link to Event (Optional)',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6B7280)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<EventResponse?>(
                            value: _selectedEvent,
                            hint: Text(
                              isSmallScreen
                                  ? 'Select event or standalone'
                                  : 'Select an event (or leave as standalone)',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                            dropdownColor: const Color(0xFF374151),
                            style: const TextStyle(color: Colors.white),
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.grey),
                            items: [
                              const DropdownMenuItem<EventResponse?>(
                                value: null,
                                child: Text(
                                  'Standalone Channel',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              ...eventProvider.events.map((event) {
                                return DropdownMenuItem<EventResponse>(
                                  value: event,
                                  child: Text(
                                    event.eventName,
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedEvent = value;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedEvent == null
                            ? 'This will create a standalone channel'
                            : 'This channel will be linked to "${_selectedEvent!.eventName}"',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16 : 24),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 8 : 12),
                          FilledButton(
                            onPressed: _isLoading ? null : _createChannel,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16 : 24,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(isSmallScreen
                                    ? 'Create'
                                    : 'Create Channel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
