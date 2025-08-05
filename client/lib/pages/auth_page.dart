import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          _buildTabBar(context),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.1, 0),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOut,
                                  )),
                                  child: child,
                                ),
                              );
                            },
                            child: _currentIndex == 0
                                ? const LoginForm(key: ValueKey('login'))
                                : const RegisterForm(key: ValueKey('register')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.radio_rounded,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Operation Won',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Secure Communication Platform',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final theme = Theme.of(context);
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Login'),
        Tab(text: 'Register'),
      ],
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: theme.colorScheme.primary,
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      indicatorPadding: const EdgeInsets.all(4),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      labelColor: theme.colorScheme.onPrimary,
      unselectedLabelColor: theme.colorScheme.onSurface,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'By continuing, you agree to our Terms of Service and Privacy Policy',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '© 2025 Operation Won. All rights reserved.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Login failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        // Login successful - permissions will be requested by AuthStateListener
        debugPrint('[AuthPage] Login successful');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return AutofillGroup(
        child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildServerSelector(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [
              AutofillHints.username,
              AutofillHints.email,
            ],
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Username or email',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: authProvider.isLoading ? null : _handleLogin,
              child: authProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDemoCredentials(context),
        ],
      ),
    ));
  }

  Widget _buildDemoCredentials(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demo Credentials:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Username: demo\nPassword: password123',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerSelector() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        // Get current endpoint name or default to 'Custom' if none selected
        final currentEndpointName =
            settingsProvider.getCurrentPredefinedEndpoint()?['name'] ??
                'Custom';

        return DropdownButtonFormField<String>(
          value: currentEndpointName,
          decoration: InputDecoration(
            labelText: 'Server',
            prefixIcon: const Icon(Icons.dns_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.wifi_find),
              tooltip: 'Test server connection',
              onPressed: () => _testServerConnection(context, settingsProvider),
            ),
          ),
          items: [
            ...SettingsProvider.predefinedEndpoints.map((endpoint) {
              return DropdownMenuItem(
                value: endpoint['name'],
                child: Text(endpoint['name']!),
              );
            }),
            const DropdownMenuItem(
              value: 'Custom',
              child: Text('Self-hosted'),
            ),
          ],
          onChanged: (value) {
            if (value != 'Custom') {
              final selectedEndpoint = SettingsProvider.predefinedEndpoints
                  .firstWhere((endpoint) => endpoint['name'] == value);
              settingsProvider.setPredefinedEndpoint(selectedEndpoint);
            } else {
              _showCustomServerDialog(context, settingsProvider);
            }
          },
        );
      },
    );
  }

  void _showCustomServerDialog(
      BuildContext context, SettingsProvider settingsProvider) {
    final controller =
        TextEditingController(text: settingsProvider.apiEndpoint);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Self-hosted'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'API Endpoint',
            hintText: 'https://api.example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final apiUrl = controller.text.trim();
              if (apiUrl.isNotEmpty) {
                final wsUrl = SettingsProvider.generateWebSocketUrl(apiUrl);
                await settingsProvider.setApiEndpoint(apiUrl);
                await settingsProvider.setWebsocketEndpoint(wsUrl);
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _testServerConnection(
      BuildContext context, SettingsProvider settingsProvider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing server connection...'),
          ],
        ),
      ),
    );

    try {
      // Create a temporary API service for testing
      final testApiService = ApiService(baseUrl: settingsProvider.apiEndpoint);
      final success = await testApiService.pingServer();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(success
                    ? 'Server is reachable!'
                    : 'Server is not responding'),
              ],
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Connection test failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Registration failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        // Registration successful - permissions will be requested by AuthStateListener
        debugPrint('[AuthPage] Registration successful');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return AutofillGroup(
        child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newUsername],
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Choose a username',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Username is required';
              }
              if (value.trim().length < 3) {
                return 'Username must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Create a secure password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _handleRegister(),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                tooltip:
                    _obscureConfirmPassword ? 'Show password' : 'Hide password',
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm Password is required';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: authProvider.isLoading ? null : _handleRegister,
              child: authProvider.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ));
  }
}
