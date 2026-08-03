import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_session.dart';
import '../../shared/platform/platform.dart';
import 'widgets/auth_form_fields.dart';

/// Registration surface — port of Swift `CreateAccountView`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.authSession,
  });

  final AuthSession authSession;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late DateTime _dateOfBirth;
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  AuthSession get _session => widget.authSession;

  static DateTime get _defaultBirthDate {
    final now = DateTime.now();
    return DateTime(now.year - 18, now.month, now.day);
  }

  DateTime get _earliestBirthDate {
    final now = DateTime.now();
    return DateTime(now.year - 120, now.month, now.day);
  }

  DateTime get _latestBirthDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isOldEnough => AgeGate.isOldEnough(_dateOfBirth);

  String? get _ageGateError =>
      _isOldEnough ? null : AgeGate.underageMessage;

  @override
  void initState() {
    super.initState();
    _dateOfBirth = _defaultBirthDate;
    _session.addListener(_onSessionChanged);
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _showLegalStub('Terms of Use');
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _showLegalStub('Privacy Policy');
  }

  @override
  void didUpdateWidget(covariant RegisterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authSession != widget.authSession) {
      oldWidget.authSession.removeListener(_onSessionChanged);
      widget.authSession.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showLegalStub(String title) {
    showAdaptiveMessage(context, '$title coming soon', title: title);
  }

  Future<void> _submit() async {
    await _session.createAccount(
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      dateOfBirth: _dateOfBirth,
    );
  }

  void _goToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_session.isWorking && _isOldEnough;

    return AuthGradientScaffold(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        children: [
          const SizedBox(height: 24),
          const AuthLogoMark(size: 100),
          const SizedBox(height: 18),
          const Text(
            'Create Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const AuthSubtitle('Join your interest bubbles'),
          const SizedBox(height: 25),
          AuthLabeledField(
            label: 'Username',
            child: AuthTextField(
              controller: _usernameController,
              hintText: 'Choose a username',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              enabled: !_session.isWorking,
            ),
          ),
          const SizedBox(height: 22),
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
          AuthDateOfBirthField(
            value: _dateOfBirth,
            firstDate: _earliestBirthDate,
            lastDate: _latestBirthDate,
            onChanged: (date) => setState(() => _dateOfBirth = date),
          ),
          if (_ageGateError != null) ...[
            const SizedBox(height: 8),
            AuthMessageText(_ageGateError!),
          ],
          const SizedBox(height: 22),
          AuthLabeledField(
            label: 'Password',
            child: AuthTextField(
              controller: _passwordController,
              hintText: 'Create a password',
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_session.isWorking,
            ),
          ),
          const SizedBox(height: 22),
          AuthLabeledField(
            label: 'Confirm Password',
            child: AuthTextField(
              controller: _confirmPasswordController,
              hintText: 'Re-enter your password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_session.isWorking,
              onSubmitted: (_) {
                if (canSubmit) {
                  _submit();
                }
              },
            ),
          ),
          if (_session.authError != null) ...[
            const SizedBox(height: 16),
            AuthMessageText(_session.authError!),
          ],
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: "By signing up, you agree to Bubbler's "),
                TextSpan(
                  text: 'Terms of Use',
                  style: const TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: _termsRecognizer,
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: _privacyRecognizer,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Opacity(
            opacity: _isOldEnough ? 1 : 0.55,
            child: AuthSubmitButton(
              label: 'Create Account',
              isLoading: _session.isWorking,
              onPressed: canSubmit ? _submit : null,
            ),
          ),
          const SizedBox(height: 16),
          AuthSwitchPrompt(
            prompt: 'Already have an account?',
            actionLabel: 'Log in',
            onAction: _session.isWorking ? null : _goToLogin,
          ),
          const SizedBox(height: 24),
          const AuthFooter('Your feed, shaped by your interests'),
        ],
      ),
    );
  }
}
