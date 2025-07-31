import 'package:flutter/material.dart';
import 'models/channel_model.dart';

class ChannelItem extends StatelessWidget {
  final ChannelResponse channel;
  final VoidCallback? onTap;
  final bool isCompact;

  const ChannelItem({
    super.key,
    required this.channel,
    this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isCompact) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: _buildCompactContent(context, theme),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: _buildFullContent(context, theme),
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              channel.channelName,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullContent(BuildContext context, ThemeData theme) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          Icons.chat_bubble_outline,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(channel.channelName, style: theme.textTheme.titleMedium),
      subtitle: Text(
        channel.eventUuid != null ? 'Event Channel' : 'Standalone',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
