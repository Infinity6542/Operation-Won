import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 768;
    final isSmallScreen = screenHeight < 700; // Detect small screens
    final isVerySmallScreen = screenHeight < 600; // Very small screens

    return Scaffold(
      backgroundColor:
          const Color(0xFF0F172A), // Dark background like the screenshot
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 48,
                vertical: isVerySmallScreen ? 4 : (isSmallScreen ? 8 : 16),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 420,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // App Logo/Branding - Responsive size
                      _buildHeader(isMobile, isSmallScreen, isVerySmallScreen),
                      SizedBox(
                          height: isVerySmallScreen
                              ? 12
                              : (isSmallScreen ? 16 : 24)),

                      // Auth Form Container - Enhanced design with gradients and borders
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF1E293B),
                              const Color(0xFF0F172A).withValues(alpha: 0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                const Color(0xFF475569).withValues(alpha: 0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(0, 15),
                            ),
                            BoxShadow(
                              color: const Color(0xFF3B82F6)
                                  .withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tab Bar
                            _buildTabBar(isSmallScreen, isVerySmallScreen),

                            // Tab Views - Show only active form with smooth transitions
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
                                  ? LoginForm(
                                      key: const ValueKey('login'),
                                      authProvider: authProvider,
                                      isMobile: isMobile,
                                      isSmallScreen: isSmallScreen,
                                      isVerySmallScreen: isVerySmallScreen)
                                  : RegisterForm(
                                      key: const ValueKey('register'),
                                      authProvider: authProvider,
                                      isMobile: isMobile,
                                      isSmallScreen: isSmallScreen,
                                      isVerySmallScreen: isVerySmallScreen),
                            ),
                          ],
                        ),
                      ),

                      // Footer with responsive spacing
                      SizedBox(
                          height: isVerySmallScreen
                              ? 8
                              : (isSmallScreen ? 12 : 16)),
                      _buildFooter(isMobile, isSmallScreen),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
      bool isMobile, bool isSmallScreen, bool isVerySmallScreen) {
    return Column(
      children: [
        // Enhanced App Logo with gradient and better shadows
        Container(
          width: isVerySmallScreen
              ? 60
              : (isSmallScreen ? 70 : (isMobile ? 80 : 100)),
          height: isVerySmallScreen
              ? 60
              : (isSmallScreen ? 70 : (isMobile ? 80 : 100)),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B82F6),
                Color(0xFF2563EB),
                Color(0xFF1D4ED8),
              ],
            ),
            borderRadius: BorderRadius.circular(isVerySmallScreen
                ? 15
                : (isSmallScreen ? 18 : (isMobile ? 20 : 25))),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                blurRadius: 25,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(
            Icons.radio_rounded,
            size: isVerySmallScreen
                ? 30
                : (isSmallScreen ? 35 : (isMobile ? 40 : 50)),
            color: Colors.white,
          ),
        ),
        SizedBox(
            height: isVerySmallScreen
                ? 12
                : (isSmallScreen ? 16 : (isMobile ? 20 : 28))),

        // App Name with improved typography
        Text(
          'Operation Won',
          style: TextStyle(
            fontSize: isVerySmallScreen
                ? 24
                : (isSmallScreen ? 28 : (isMobile ? 32 : 40)),
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(
            height: isVerySmallScreen
                ? 6
                : (isSmallScreen ? 8 : (isMobile ? 10 : 14))),

        // Subtitle with better styling
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            'Secure Communication Platform',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: isVerySmallScreen
                  ? 12
                  : (isSmallScreen ? 14 : (isMobile ? 15 : 16)),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isSmallScreen, bool isVerySmallScreen) {
    return Container(
      margin:
          EdgeInsets.all(isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16)),
      decoration: BoxDecoration(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF475569).withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF3B82F6),
                Color(0xFF2563EB),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(6),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16),
            letterSpacing: 0.3,
          ),
          tabs: [
            Tab(
              height: isVerySmallScreen ? 44 : (isSmallScreen ? 48 : 52),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: isVerySmallScreen ? 16 : 18,
                  ),
                  const SizedBox(width: 6),
                  const Text('Sign In'),
                ],
              ),
            ),
            Tab(
              height: isVerySmallScreen ? 44 : (isSmallScreen ? 48 : 52),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_rounded,
                    size: isVerySmallScreen ? 16 : 18,
                  ),
                  const SizedBox(width: 6),
                  const Text('Sign Up'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile, bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF475569).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security_rounded,
                size: 14,
                color: Colors.grey[400],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isSmallScreen ? 11 : (isMobile ? 12 : 13),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : (isMobile ? 10 : 12)),
          Text(
            '© 2025 Operation Won. All rights reserved.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: isSmallScreen ? 9 : (isMobile ? 10 : 11),
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  final AuthProvider authProvider;
  final bool isMobile;
  final bool isSmallScreen;
  final bool isVerySmallScreen;

  const LoginForm(
      {super.key,
      required this.authProvider,
      required this.isMobile,
      required this.isSmallScreen,
      required this.isVerySmallScreen});

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

    final success = await widget.authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      if (success) {
        // Navigation will be handled by AuthenticationFlow
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login successful'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.authProvider.error ?? 'Login failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back',
              style: TextStyle(
                fontSize: widget.isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: widget.isMobile ? 4 : 8),
            Text(
              'Sign in to your account to continue',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: widget.isMobile ? 14 : 16,
              ),
            ),
            SizedBox(height: widget.isMobile ? 16 : 24),

            // Username Field
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Enter your username',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
            ),
            SizedBox(height: widget.isMobile ? 12 : 16),

            // Password Field
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[400],
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            SizedBox(height: widget.isMobile ? 20 : 24),

            // Login Button
            SizedBox(
              width: double.infinity,
              height: widget.isMobile ? 48 : 52,
              child: FilledButton(
                onPressed: widget.authProvider.isLoading ? null : _handleLogin,
                child: widget.authProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            SizedBox(height: widget.isMobile ? 12 : 16),

            // Demo Credentials (for testing)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(widget.isMobile ? 12 : 14),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo Credentials:',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[300],
                    ),
                  ),
                  SizedBox(height: widget.isMobile ? 4 : 6),
                  Text(
                    'Username: demo\nPassword: password123',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: widget.isMobile ? 11 : 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[300],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(icon, color: Colors.grey[400]),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF475569),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RegisterForm extends StatefulWidget {
  final AuthProvider authProvider;
  final bool isMobile;
  final bool isSmallScreen;
  final bool isVerySmallScreen;

  const RegisterForm(
      {super.key,
      required this.authProvider,
      required this.isMobile,
      required this.isSmallScreen,
      required this.isVerySmallScreen});

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

    final success = await widget.authProvider.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      if (success) {
        // Navigation will be handled by AuthenticationFlow
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.authProvider.error ?? 'Registration failed'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget.isVerySmallScreen
          ? 12
          : (widget.isSmallScreen ? 14 : (widget.isMobile ? 16 : 24))),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create account',
              style: TextStyle(
                fontSize: widget.isVerySmallScreen
                    ? 18
                    : (widget.isSmallScreen ? 19 : (widget.isMobile ? 20 : 24)),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(
                height: widget.isVerySmallScreen
                    ? 2
                    : (widget.isSmallScreen ? 3 : (widget.isMobile ? 4 : 8))),
            Text(
              'Join the secure communication platform',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: widget.isVerySmallScreen
                    ? 12
                    : (widget.isSmallScreen ? 13 : (widget.isMobile ? 14 : 16)),
              ),
            ),
            SizedBox(
                height: widget.isVerySmallScreen
                    ? 10
                    : (widget.isSmallScreen
                        ? 12
                        : (widget.isMobile ? 16 : 20))),

            // Username Field
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Choose a username',
              icon: Icons.person_outline,
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
            SizedBox(
                height: widget.isVerySmallScreen
                    ? 6
                    : (widget.isSmallScreen ? 8 : (widget.isMobile ? 10 : 12))),

            // Email Field
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Enter your email address',
              icon: Icons.email_outlined,
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
            SizedBox(
                height: widget.isVerySmallScreen
                    ? 6
                    : (widget.isSmallScreen ? 8 : (widget.isMobile ? 10 : 12))),

            // Password Field
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Create a password',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[400],
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            SizedBox(
                height: widget.isVerySmallScreen
                    ? 6
                    : (widget.isSmallScreen ? 8 : (widget.isMobile ? 10 : 12))),

            // Confirm Password Field
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Confirm your password',
              icon: Icons.lock_outline,
              obscureText: _obscureConfirmPassword,
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
                  color: Colors.grey[400],
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            SizedBox(
                height: widget.isVerySmallScreen
                    ? 10
                    : (widget.isSmallScreen
                        ? 12
                        : (widget.isMobile ? 14 : 18))),

            // Register Button
            SizedBox(
              width: double.infinity,
              height: widget.isVerySmallScreen
                  ? 44
                  : (widget.isSmallScreen ? 46 : (widget.isMobile ? 48 : 52)),
              child: FilledButton(
                onPressed:
                    widget.authProvider.isLoading ? null : _handleRegister,
                child: widget.authProvider.isLoading
                    ? SizedBox(
                        width: widget.isVerySmallScreen ? 16 : 20,
                        height: widget.isVerySmallScreen ? 16 : 20,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: widget.isVerySmallScreen
                              ? 14
                              : (widget.isSmallScreen ? 15 : 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[300],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(icon, color: Colors.grey[400]),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFF475569),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
