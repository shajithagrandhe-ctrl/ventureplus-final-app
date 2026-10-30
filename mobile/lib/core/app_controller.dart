import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_transport.dart';
import '../data/connected_repository.dart';
import '../data/offline_repository.dart';
import '../data/repository.dart';
import '../data/storage.dart';
import 'models.dart';

export 'models.dart';
export 'permissions.dart';
export 'demo_prefills.dart';
export '../data/repository.dart';
export '../data/api_transport.dart';
export '../data/connected_repository.dart';
export '../data/offline_repository.dart';
export '../data/storage.dart';

class AppController extends ChangeNotifier {
  AppController({required this.transport, required this.preferences}) {
    final api = transport;
    if (api is DioApiTransport) {
      api.onSessionWarning = (message) {
        sessionWarning = message;
        _notify();
      };
    }
  }
  final ApiTransport transport;
  final KeyValueStore preferences;
  static const modeKey = 'ventureplus.mode';
  static const roleKey = 'ventureplus.demoRole';

  static Future<AppController> create() async {
    const base = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://ventureplus123.vercel.app/api',
    );
    final preferences = PreferencesStore(await SharedPreferences.getInstance());
    return AppController(
      transport: DioApiTransport(
        baseUrl: base,
        cookieStore: const SecureStore(),
      ),
      preferences: preferences,
    );
  }

  UserIdentity? user;
  SessionMode? mode;
  VentureRepository? repository;
  bool _working = false;
  bool _clearingSession = false;
  bool get busy => _working || _clearingSession;
  String? error;
  String? sessionWarning;
  String? sessionNotice;
  bool _disposed = false;
  bool get isOffline => mode == SessionMode.offlineDemo;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    error = null;
    sessionNotice = null;
    _notify();
  }

  String _message(Object failure) => failure is AppFailure
      ? failure.message
      : 'The action could not be completed. Please try again.';

  Future<bool> _action(Future<void> Function() work) async {
    if (busy) return false;
    _working = true;
    error = null;
    sessionNotice = null;
    _notify();
    try {
      await work();
      return true;
    } on Object catch (failure) {
      error = _message(failure);
      return false;
    } finally {
      _working = false;
      _notify();
    }
  }

  void _clearIdentity() {
    user = null;
    mode = null;
    repository = null;
  }

  void _expired() {
    if (mode != SessionMode.connected) return;
    _clearingSession = true;
    _clearIdentity();
    error = 'Your session expired. Please sign in again.';
    _notify();
    unawaited(
      _clearSavedSession()
          .catchError((Object failure) {
            error = 'Your session expired. Saved session cleanup failed; please sign in again.';
          })
          .whenComplete(() {
            _clearingSession = false;
            _notify();
          }),
    );
  }

  Future<void> _clearSavedSession() async {
    await preferences.remove(modeKey);
    await preferences.remove(roleKey);
    await transport.clear();
  }

  Future<bool> restore() => _action(() async {
    _clearIdentity();
    final savedMode = await preferences.read(modeKey);
    if (savedMode == SessionMode.offlineDemo.name) {
      final role = Role.parse(await preferences.read(roleKey));
      final offline = await OfflineRepository.open(preferences, role);
      user = offline.user;
      mode = SessionMode.offlineDemo;
      repository = offline;
    } else if (savedMode == SessionMode.connected.name) {
      await transport.restore();
      try {
        final response = await transport.request('GET', '/auth/me');
        final identity = UserIdentity.fromJson(
          jsonObject(jsonObject(response['data'])['user']),
        );
        user = identity;
        mode = SessionMode.connected;
        repository = ConnectedRepository(
          transport,
          identity,
          onUnauthorized: _expired,
        );
      } on AppFailure catch (failure) {
        if (failure.statusCode == 401 || failure.statusCode == 403) {
          await _clearSavedSession();
        }
        rethrow;
      }
    }
  });

  Future<bool> login(String email, String password) => _action(() async {
    _clearIdentity();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim()) ||
        password.length < 6) {
      throw const AppFailure(
        'Enter a valid email and a password with at least 6 characters.',
      );
    }
    await preferences.remove(modeKey);
    await transport.clear();
    try {
      await transport.request(
        'POST',
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final response = await transport.request('GET', '/auth/me');
      final identity = UserIdentity.fromJson(
        jsonObject(jsonObject(response['data'])['user']),
      );
      await preferences.write(modeKey, SessionMode.connected.name);
      user = identity;
      mode = SessionMode.connected;
      repository = ConnectedRepository(
        transport,
        identity,
        onUnauthorized: _expired,
      );
    } on Object {
      await transport.clear();
      rethrow;
    }
  });

  Future<bool> enterOffline(Role role) => _action(() async {
    final offline = await OfflineRepository.open(preferences, role);
    await preferences.write(roleKey, role.wireName);
    await preferences.write(modeKey, SessionMode.offlineDemo.name);
    user = offline.user;
    mode = SessionMode.offlineDemo;
    repository = offline;
  });

  Future<bool> logout() => _action(() async {
    final wasConnected = mode == SessionMode.connected;
    _clearIdentity();
    Object? remoteError;
    if (wasConnected) {
      try {
        await transport.request('POST', '/auth/logout');
      } on Object catch (failure) {
        remoteError = failure;
      }
    }
    await preferences.remove(modeKey);
    await preferences.remove(roleKey);
    // Offline logout has no transport call, including session restoration.
    if (wasConnected) await transport.clear();
    if (remoteError != null) {
      throw const AppFailure(
        'Signed out on this device. The server could not confirm sign-out.',
      );
    }
  });

  /// The server has already changed the password and revoked its sessions.
  /// Local cleanup failures must never invite retrying the password mutation.
  Future<void> passwordChanged() async {
    _clearingSession = true;
    _clearIdentity();
    error = null;
    sessionNotice = 'Password updated. Sign in again with your new password.';
    _notify();
    try {
      await _clearSavedSession();
    } on Object {
      error = 'The password was updated, but saved session cleanup failed on this device. Please sign in again.';
    } finally {
      _clearingSession = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final api = transport;
    if (api is DioApiTransport) api.onSessionWarning = null;
    super.dispose();
  }
}
