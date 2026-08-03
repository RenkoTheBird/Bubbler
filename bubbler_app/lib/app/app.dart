import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_session.dart';
import '../core/auth/token_store.dart';
import '../data/repositories/auth_repository.dart';
import 'router.dart';
import 'theme.dart';

/// Root app shell: DI, session restore, and auth gate (Swift `ContentView`).
class BubblerApp extends StatefulWidget {
  const BubblerApp({super.key});

  @override
  State<BubblerApp> createState() => _BubblerAppState();
}

class _BubblerAppState extends State<BubblerApp> {
  late final ApiClient _apiClient;
  late final AuthSession _authSession;
  late final Future<void> _restoreFuture;

  @override
  void initState() {
    super.initState();

    final tokenStore = TokenStore();
    late final AuthSession session;
    final apiClient = ApiClient(
      accessTokenProvider: () => session.accessToken,
    );
    session = AuthSession(
      authRepository: AuthRepository(apiClient),
      tokenStore: tokenStore,
    );

    _apiClient = apiClient;
    _authSession = session;
    _restoreFuture = session.restore();
  }

  @override
  void dispose() {
    _authSession.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bubbler',
      debugShowCheckedModeBanner: false,
      theme: BubblerTheme.light(),
      home: FutureBuilder<void>(
        future: _restoreFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AuthRestoreSplash();
          }
          return AuthGate(
            authSession: _authSession,
            apiClient: _apiClient,
          );
        },
      ),
    );
  }
}
