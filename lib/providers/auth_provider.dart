// lib/providers/auth_provider.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/api_response_model.dart';
import '../data/models/user_model.dart';
import '../data/services/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepository();

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _authToken;
  String? _refreshToken;
  String _errorMessage = '';

  AuthStatus get status    => _status;
  UserModel? get user      => _user;
  String? get authToken    => _authToken;
  String? get refreshToken => _refreshToken;
  String get errorMessage  => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  static const _kAuthToken    = 'auth_token';
  static const _kRefreshToken = 'refresh_token';

  // ── Init: load token dari storage ────────────
  Future<void> init() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _authToken    = prefs.getString(_kAuthToken);
    _refreshToken = prefs.getString(_kRefreshToken);

    if (_authToken != null) {
      final result = await _repository.getMe(authToken: _authToken!);
      if (result.success && result.data != null) {
        _user   = result.data;
        _status = AuthStatus.authenticated;
      } else {
        final refreshed = await _tryRefresh();
        if (!refreshed) {
          await _clearTokens();
          _status = AuthStatus.unauthenticated;
        }
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Register ──────────────────────────────────
  Future<ApiResponse<String>> register({
    required String name,
    required String username,
    required String password,
  }) async {
    return _repository.register(
        name: name, username: username, password: password);
  }

  // ── Login ─────────────────────────────────────
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    notifyListeners();

    final result =
    await _repository.login(username: username, password: password);
    if (result.success && result.data != null) {
      _authToken    = result.data!['authToken'];
      _refreshToken = result.data!['refreshToken'];
      await _saveTokens();

      final me = await _repository.getMe(authToken: _authToken!);
      if (me.success && me.data != null) {
        _user   = me.data;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
    }

    _errorMessage = result.message;
    _status = AuthStatus.error;
    notifyListeners();
    return false;
  }

  // ── Logout ────────────────────────────────────
  Future<void> logout() async {
    if (_authToken != null) {
      await _repository.logout(authToken: _authToken!);
    }
    await _clearTokens();
    _user   = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Fetch profil ──────────────────────────────
  Future<void> fetchMe() async {
    final token = _authToken;
    if (token == null) return;
    final result = await _repository.getMe(authToken: token);
    if (result.success && result.data != null) {
      _user = result.data;
      notifyListeners();
    }
  }

  // ── Update info akun (nama & username) ────────
  Future<ApiResponse<void>> updateMe({
    required String authToken,
    required String name,
    required String username,
  }) async {
    final result = await _repository.updateMe(
        authToken: authToken, name: name, username: username);
    if (result.success) await fetchMe();
    return result;
  }

  // ── Ganti kata sandi ──────────────────────────
  Future<ApiResponse<void>> updatePassword({
    required String authToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    return _repository.updatePassword(
      authToken: authToken,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  // ── Upload foto profil ────────────────────────
  Future<ApiResponse<void>> updatePhoto({
    required String authToken,
    File? imageFile,
    Uint8List? imageBytes,
    String imageFilename = 'photo.jpg',
  }) async {
    final result = await _repository.updatePhoto(
      authToken: authToken,
      imageFile: imageFile,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
    );
    if (result.success) await fetchMe();
    return result;
  }

  // ── Private helpers ───────────────────────────
  Future<bool> _tryRefresh() async {
    if (_authToken == null || _refreshToken == null) return false;
    final result = await _repository.refreshToken(
      authToken: _authToken!,
      refreshToken: _refreshToken!,
    );
    if (result.success && result.data != null) {
      _authToken    = result.data!['authToken'];
      _refreshToken = result.data!['refreshToken'];
      await _saveTokens();
      final me = await _repository.getMe(authToken: _authToken!);
      if (me.success && me.data != null) {
        _user   = me.data;
        _status = AuthStatus.authenticated;
        return true;
      }
    }
    return false;
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_authToken != null)    prefs.setString(_kAuthToken, _authToken!);
    if (_refreshToken != null) prefs.setString(_kRefreshToken, _refreshToken!);
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_kAuthToken);
    prefs.remove(_kRefreshToken);
    _authToken    = null;
    _refreshToken = null;
  }
}