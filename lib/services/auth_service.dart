import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// Service managing user authentication, profile state, and session lifecycle via Supabase Auth.
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  bool _isLoading = false;

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  UserModel? get currentUser {
    final client = _supabase;
    if (client != null) {
      final user = client.auth.currentUser;
      if (user != null) {
        return UserModel(
          id: user.id,
          fullName: user.userMetadata?['full_name'] ?? _currentUser?.fullName ?? user.email?.split('@').first ?? '',
          email: user.email ?? '',
          phone: user.phone ?? user.userMetadata?['phone'] ?? _currentUser?.phone ?? '',
          firstName: user.userMetadata?['first_name'] ?? _currentUser?.firstName,
          lastName: user.userMetadata?['last_name'] ?? _currentUser?.lastName,
          dateOfBirth: user.userMetadata?['dob'] ?? _currentUser?.dateOfBirth,
          gender: user.userMetadata?['gender'] ?? _currentUser?.gender,
        );
      }
    }
    return _currentUser;
  }

  bool get isAuthenticated {
    final client = _supabase;
    if (client != null && client.auth.currentUser != null) {
      return true;
    }
    return _currentUser != null;
  }

  bool get isLoading => _isLoading;

  /// Authenticates user with email & password via Supabase.
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = _supabase;
      if (client != null) {
        final AuthResponse response = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        final user = response.user;
        if (user != null) {
          _currentUser = UserModel(
            id: user.id,
            fullName: user.userMetadata?['full_name'] ?? email.split('@').first,
            email: user.email ?? email,
            phone: user.phone ?? user.userMetadata?['phone'] ?? '',
            firstName: user.userMetadata?['first_name'],
            lastName: user.userMetadata?['last_name'],
            dateOfBirth: user.userMetadata?['dob'],
            gender: user.userMetadata?['gender'],
          );
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } else {
        // Fallback local login if Supabase client uninitialized
        _currentUser = UserModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fullName: email.split('@').first,
          email: email,
          phone: '',
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      throw e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw e.toString();
    }
  }

  /// Registers a new account with email & password via Supabase.
  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = _supabase;
      if (client != null) {
        final AuthResponse response = await client.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': fullName,
            'phone': phone,
          },
        );

        final user = response.user;
        if (user != null) {
          _currentUser = UserModel(
            id: user.id,
            fullName: fullName,
            email: email,
            phone: phone,
          );
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } else {
        _currentUser = UserModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          fullName: fullName,
          email: email,
          phone: phone,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      throw e.message;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw e.toString();
    }
  }

  /// Updates current user profile details in Supabase user metadata.
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? dateOfBirth,
    String? gender,
    String? fullName,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = _supabase;
      if (client != null) {
        final currentUser = client.auth.currentUser;
        final newMetadata = <String, dynamic>{};
        if (fullName != null) newMetadata['full_name'] = fullName;
        if (firstName != null) newMetadata['first_name'] = firstName;
        if (lastName != null) newMetadata['last_name'] = lastName;
        if (dateOfBirth != null) newMetadata['dob'] = dateOfBirth;
        if (gender != null) newMetadata['gender'] = gender;
        if (phone != null) newMetadata['phone'] = phone;

        if (currentUser != null) {
          final res = await client.auth.updateUser(
            UserAttributes(
              data: newMetadata,
            ),
          );
          final updatedUser = res.user;
          if (updatedUser != null) {
            _currentUser = UserModel(
              id: updatedUser.id,
              fullName: fullName ?? _currentUser?.fullName ?? '',
              email: updatedUser.email ?? _currentUser?.email ?? '',
              phone: phone ?? _currentUser?.phone ?? '',
              firstName: firstName ?? _currentUser?.firstName,
              lastName: lastName ?? _currentUser?.lastName,
              dateOfBirth: dateOfBirth ?? _currentUser?.dateOfBirth,
              gender: gender ?? _currentUser?.gender,
            );
          }
        }
      } else if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          fullName: fullName,
          firstName: firstName,
          lastName: lastName,
          dateOfBirth: dateOfBirth,
          gender: gender,
          phone: phone,
        );
      }
    } catch (_) {
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          fullName: fullName,
          firstName: firstName,
          lastName: lastName,
          dateOfBirth: dateOfBirth,
          gender: gender,
          phone: phone,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs out the user and clears Supabase session.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = _supabase;
      if (client != null) {
        await client.auth.signOut();
      }
    } catch (_) {}

    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }
}
