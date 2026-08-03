import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_session.dart';
import '../../shared/platform/platform.dart';
import 'register_screen.dart';
import 'widgets/auth_form_fields.dart';

/// Login surface — port of Swift `LoginView`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authSession,
    required this.apiClient,
  });

  final AuthSession authSession;
  final ApiClient apiClient;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthBackendStatus _backendStatus = AuthBackendStatus.checking;

  AuthSession get _session => widget.authSession;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _refreshBackend();
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authSession != widget.authSession) {
      oldWidget.authSession.removeListener(_onSessionChanged);
      widget.authSession.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshBackend() async {
    setState(() => _backendStatus = AuthBackendStatus.checking);
    try {
      final health = await widget.apiClient.health();
      if (!mounted) {
        return;
      }
      setState(() {
        _backendStatus = health.isOk
            ? AuthBackendStatus.connected
            : AuthBackendStatus.unavailable;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _backendStatus = AuthBackendStatus.unavailable);
    }
  }

  Future<void> _submit() async {
    await _session.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _openCreateAccount() {
    Navigator.of(context).push(
      adaptivePageRoute<void>(
        context: context,
        builder: (_) => RegisterScreen(authSession: _session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthGradientScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
                  const AuthLogoMark(size: 120),
                  const SizedBox(height: 18),
                  Text(
                    'Bubbler',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const AuthSubtitle('See what you actually care about'),
                  const SizedBox(height: 12),
                  Center(child: AuthBackendStatusChip(status: _backendStatus)),
                  const SizedBox(height: 30),
                  AuthLabeledField(
                    label: 'Email',
                    child: AuthTextField(
                      controller: _emailController,
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      enabled: !_session.isWorking,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthLabeledField(
                    label: 'Password',
                    child: AuthTextField(
                      controller: _passwordController,
                      hintText: 'Enter your password',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      enabled: !_session.isWorking,
                      onSubmitted: (_) {
                        if (!_session.isWorking) {
                          _submit();
                        }
                      },
                    ),
                  ),
                  if (_session.authError != null) ...[
                    const SizedBox(height: 16),
                    AuthMessageText(_session.authError!),
                  ],
                  const SizedBox(height: 26),
                  AuthSubmitButton(
                    label: 'Log In',
                    isLoading: _session.isWorking,
                    onPressed: _session.isWorking ? null : _submit,
                  ),
                  const SizedBox(height: 16),
                  AuthSwitchPrompt(
                    prompt: 'New to Bubbler?',
                    actionLabel: 'Create account',
                    onAction:
                        _session.isWorking ? null : _openCreateAccount,
                  ),
                ],
              ),
            ),
            const AuthFooter('Powered by interest-based bubbles'),
          ],
        ),
      ),
    );
  }
}
