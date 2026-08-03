import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_session.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/widgets/auth_form_fields.dart';
import 'theme.dart';

/// Auth gate matching Swift `ContentView`: signed-in home vs login stack.
///
/// Main tabs arrive in Phase 5; until then signed-in users see a temporary
/// shell with sign-out (needed for Phase 1 exit criteria).
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authSession,
    required this.apiClient,
  });

  final AuthSession authSession;
  final ApiClient apiClient;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _pendingSuccessClear;

  AuthSession get _session => widget.authSession;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authSession != widget.authSession) {
      oldWidget.authSession.removeListener(_onSessionChanged);
      widget.authSession.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});

    final message = _session.successMessage;
    if (message != null && message != _pendingSuccessClear) {
      _pendingSuccessClear = message;
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) {
          return;
        }
        if (_session.successMessage == message) {
          _session.clearSuccessMessage();
        }
        if (_pendingSuccessClear == message) {
          _pendingSuccessClear = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        KeyedSubtree(
          // Reset navigation when auth flips (Swift `.id(isSignedIn)`).
          key: ValueKey(_session.isSignedIn),
          child: _session.isSignedIn
              ? _SignedInPlaceholder(authSession: _session)
              : LoginScreen(
                  authSession: _session,
                  apiClient: widget.apiClient,
                ),
        ),
        if (_session.successMessage != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 18,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Text(
                      _session.successMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Temporary post-auth home until Phase 5 `HomeShell` / main tabs.
class _SignedInPlaceholder extends StatelessWidget {
  const _SignedInPlaceholder({required this.authSession});

  final AuthSession authSession;

  @override
  Widget build(BuildContext context) {
    return AuthGradientScaffold(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(),
            const AuthLogoMark(size: 100),
            const SizedBox(height: 18),
            Text(
              'Bubbler',
              style: TextStyle(
                fontSize: 42,
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
            const AuthSubtitle("You're signed in"),
            if (authSession.userId != null) ...[
              const SizedBox(height: 8),
              Text(
                'User #${authSession.userId}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 36),
            AuthSubmitButton(
              label: 'Sign Out',
              onPressed: () => authSession.signOut(),
            ),
            const Spacer(),
            const AuthFooter('Main tabs arrive in a later phase'),
          ],
        ),
      ),
    );
  }
}

/// Brief splash while [AuthSession.restore] runs.
class AuthRestoreSplash extends StatelessWidget {
  const AuthRestoreSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: BubblerTheme.backgroundGradient),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
