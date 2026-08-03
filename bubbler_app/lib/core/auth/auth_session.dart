import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';
import '../api/api_exception.dart';
import 'token_store.dart';

/// Signup age floor (EU-friendly GDPR Art. 8), matching Swift `AgeGate`.
abstract final class AgeGate {
  static const int minimumAge = 16;

  static int age(DateTime birthDate, {DateTime? on}) {
    final reference = (on ?? DateTime.now()).toLocal();
    final birth = birthDate.toLocal();
    var years = reference.year - birth.year;
    if (reference.month < birth.month ||
        (reference.month == birth.month && reference.day < birth.day)) {
      years -= 1;
    }
    return years;
  }

  static bool isOldEnough(DateTime dateOfBirth, {DateTime? on}) {
    return age(dateOfBirth, on: on) >= minimumAge;
  }

  static String get underageMessage =>
      'You must be at least $minimumAge years old to use Bubbler.';
}

/// Session state: login / register / sign-out / cold-start restore.
///
/// Mirrors Swift `AuthSession`. Holds the in-memory access token for the
/// API client's Bearer provider; persists via [TokenStore].
class AuthSession extends ChangeNotifier {
  AuthSession({
    required AuthRepository authRepository,
    required TokenStore tokenStore,
  })  : _authRepository = authRepository,
        _tokenStore = tokenStore;

  final AuthRepository _authRepository;
  final TokenStore _tokenStore;

  String? _accessToken;
  int? _userId;
  String? authError;
  String? successMessage;
  bool isWorking = false;
  bool _restored = false;

  String? get accessToken => _accessToken;
  int? get userId => _userId;
  bool get isSignedIn => _accessToken != null;

  /// Whether [restore] has completed at least once.
  bool get isRestored => _restored;

  /// Loads any persisted token (cold start). Safe to call more than once.
  Future<void> restore() async {
    final token = await _tokenStore.loadAccessToken();
    _accessToken = token;
    _userId = restoredUserId(token);
    _restored = true;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = _normalizedEmail(email);

    if (trimmedEmail.isEmpty) {
      authError = 'Enter your email address.';
      notifyListeners();
      return;
    }

    if (password.isEmpty) {
      authError = 'Enter your password.';
      notifyListeners();
      return;
    }

    await _performAuthAction(
      () => _authRepository.login(email: trimmedEmail, password: password),
      unauthorizedErrorMessage: 'Incorrect username or password.',
    );
  }

  Future<void> createAccount({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
    required DateTime dateOfBirth,
  }) async {
    final trimmedUsername = username.trim();
    final trimmedEmail = _normalizedEmail(email);

    if (trimmedUsername.isEmpty) {
      authError = 'Enter a username.';
      notifyListeners();
      return;
    }

    if (trimmedUsername.length > 20) {
      authError = 'Username must be 20 characters or fewer.';
      notifyListeners();
      return;
    }

    if (trimmedEmail.isEmpty) {
      authError = 'Enter your email address.';
      notifyListeners();
      return;
    }

    if (!AgeGate.isOldEnough(dateOfBirth)) {
      authError = AgeGate.underageMessage;
      notifyListeners();
      return;
    }

    if (password.length < 5) {
      authError = 'Password must be at least 5 characters.';
      notifyListeners();
      return;
    }

    if (password.length > 40) {
      authError = 'Password must be 40 characters or fewer.';
      notifyListeners();
      return;
    }

    if (password != confirmPassword) {
      authError = 'Passwords do not match.';
      notifyListeners();
      return;
    }

    final didCreateAccount = await _performAuthAction(
      () => _authRepository.register(
        username: trimmedUsername,
        email: trimmedEmail,
        password: password,
        dateOfBirth: dateOfBirth,
      ),
    );

    if (didCreateAccount) {
      successMessage = 'Account created successfully!';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _userId = null;
    authError = null;
    successMessage = null;
    notifyListeners();
    await _tokenStore.deleteAccessToken();
  }

  void clearSuccessMessage() {
    successMessage = null;
    notifyListeners();
  }

  void showSuccessMessage(String message) {
    successMessage = message;
    notifyListeners();
  }

  Future<bool> _performAuthAction(
    Future<AuthResponse> Function() action, {
    String? unauthorizedErrorMessage,
  }) async {
    authError = null;
    successMessage = null;
    isWorking = true;
    notifyListeners();

    try {
      final response = await action();
      await _tokenStore.saveAccessToken(response.accessToken);
      _accessToken = response.accessToken;
      _userId = response.userId;
      return true;
    } on ApiUnauthorized {
      authError = unauthorizedErrorMessage ?? const ApiUnauthorized().message;
      return false;
    } catch (error) {
      authError = error.toString();
      return false;
    } finally {
      isWorking = false;
      notifyListeners();
    }
  }

  static String _normalizedEmail(String email) {
    return email.trim().toLowerCase();
  }

  /// Decodes `sub` from a JWT payload without verifying the signature.
  @visibleForTesting
  static int? restoredUserId(String? token) {
    if (token == null) {
      return null;
    }

    final segments = token.split('.');
    if (segments.length < 2) {
      return null;
    }

    try {
      final normalized = base64Url.normalize(segments[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final subject = payload['sub'];
      if (subject is String) {
        return int.tryParse(subject);
      }
      if (subject is int) {
        return subject;
      }
      return null;
    } on Object {
      return null;
    }
  }
}
