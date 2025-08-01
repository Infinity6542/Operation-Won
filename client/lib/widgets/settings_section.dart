import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Theme setting - only rebuilds when theme changes
        Selector<SettingsProvider, String>(
          selector: (context, settings) => settings.themeModeName,
          builder: (context, themeMode, child) {
            return _ThemeDropdown(currentTheme: themeMode);
          },
        ),
        const SizedBox(height: 16),

        // PTT Mode setting - only rebuilds when PTT mode changes
        Selector<SettingsProvider, String>(
          selector: (context, settings) => settings.pttMode,
          builder: (context, pttMode, child) {
            return _PTTModeDropdown(currentMode: pttMode);
          },
        ),
        const SizedBox(height: 16),

        // Magic Mic setting - only rebuilds when magic mic changes
        Selector<SettingsProvider, bool>(
          selector: (context, settings) => settings.magicMicEnabled,
          builder: (context, magicMicEnabled, child) {
            return _MagicMicSwitch(isEnabled: magicMicEnabled);
          },
        ),
      ],
    );
  }
}

class _ThemeDropdown extends StatelessWidget {
  const _ThemeDropdown({required this.currentTheme});

  final String currentTheme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Theme'),
      subtitle: const Text('Choose your preferred theme'),
      trailing: DropdownButton<String>(
        value: currentTheme,
        items: const [
          DropdownMenuItem(value: 'dark', child: Text('Dark')),
          DropdownMenuItem(value: 'light', child: Text('Light')),
          DropdownMenuItem(value: 'system', child: Text('System Default')),
        ],
        onChanged: (value) {
          if (value != null) {
            context.read<SettingsProvider>().setThemeMode(value);
          }
        },
      ),
    );
  }
}

class _PTTModeDropdown extends StatelessWidget {
  const _PTTModeDropdown({required this.currentMode});

  final String currentMode;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('PTT Mode'),
      subtitle: const Text('Push-to-talk behavior'),
      trailing: DropdownButton<String>(
        value: currentMode,
        items: const [
          DropdownMenuItem(value: 'hold', child: Text('Hold')),
          DropdownMenuItem(value: 'tap', child: Text('Tap')),
        ],
        onChanged: (value) {
          if (value != null) {
            context.read<SettingsProvider>().setPttMode(value);
          }
        },
      ),
    );
  }
}

class _MagicMicSwitch extends StatelessWidget {
  const _MagicMicSwitch({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Magic Mic'),
      subtitle: const Text('Noise suppression and automatic gain control'),
      value: isEnabled,
      onChanged: (value) {
        context.read<SettingsProvider>().setMagicMicEnabled(value);
      },
    );
  }
}
