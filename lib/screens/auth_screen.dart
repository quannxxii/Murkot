import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/unlumen/murkot_fx.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authService,
    required this.settingsService,
  });

  final AuthService authService;
  final SettingsService settingsService;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardKey = GlobalKey();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isRegister = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final error = _isRegister
        ? await widget.authService.register(
            login: _loginController.text,
            password: _passwordController.text,
            email: _emailController.text,
          )
        : await widget.authService.login(
            login: _loginController.text,
            password: _passwordController.text,
            email: _emailController.text,
          );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = context.strings;

    return Scaffold(
      body: ListenableBuilder(
        listenable: widget.settingsService,
        builder: (context, _) {
          // Spotlight temporarily disabled (keep widget for later restore).
          return AuthWavySpotlight(
            cardKey: _cardKey,
            enabled: false,
            child: MurkotAtmosphere(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Material(
                        key: _cardKey,
                        color:
                            theme.colorScheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(24),
                        elevation: 2,
                        child: Stack(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 28, 24, 24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Center(
                                        child: MurkotLogoMark(size: 200)),
                                    const SizedBox(height: 18),
                                    Text(
                                      'MURKOT',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 3.2,
                                        fontSize: 34,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      strings.appTagline,
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isRegister
                                          ? strings.createAccount
                                          : strings.signInAccount,
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    TextFormField(
                                      controller: _loginController,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: strings.login,
                                        prefixIcon:
                                            const Icon(Icons.person_outline),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return strings.enterLogin;
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText: strings.email,
                                        prefixIcon:
                                            const Icon(Icons.email_outlined),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            !value.contains('@')) {
                                          return strings.enterEmail;
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      decoration: InputDecoration(
                                        labelText: strings.passwordHint,
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: MurkotFloatingTooltip(
                                          message: _obscurePassword
                                              ? strings.showPassword
                                              : strings.hidePassword,
                                          settings: widget.settingsService,
                                          child: IconButton(
                                            tooltip: '',
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.length < 6) {
                                          return strings.minPassword;
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        _error!,
                                        style: TextStyle(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 20),
                                    FilledButton(
                                      onPressed: _isLoading ? null : _submit,
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: MurkotLoaderCompact(),
                                            )
                                          : Text(_isRegister
                                              ? strings.register
                                              : strings.signIn),
                                    ),
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => setState(() {
                                                _isRegister = !_isRegister;
                                                _error = null;
                                              }),
                                      child: Text(
                                        _isRegister
                                            ? strings.haveAccount
                                            : strings.noAccount,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    OutlinedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => widget.settingsService
                                              .setGuest(true),
                                      child: Text(strings.guestEnter),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      strings.guestHint,
                                      textAlign: TextAlign.center,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: MurkotThemeSwitch(
                                settings: widget.settingsService,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
