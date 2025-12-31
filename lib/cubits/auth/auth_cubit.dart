import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'auth_state.dart';
import '../../services/auth_service.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  final TextEditingController urlCtrl = TextEditingController(text: "http://");
  final TextEditingController userCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  AuthCubit(this._authService) : super(AuthInitial());

  // Check SharedPreferences on app start
  Future<void> checkSession() async {
    emit(AuthLoading());
    try {
      final session = await _authService.restoreSession();
      if (session != null) {
        emit(
          AuthAuthenticated(
            serverUrl: session['url']!,
            accessToken: session['token']!,
            userId: session['userId']!,
          ),
        );
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> login(String url, String username, String password) async {
    emit(AuthLoading());
    try {
      final result = await _authService.login(url, username, password);
      emit(
        AuthAuthenticated(
          serverUrl: result['url']!,
          accessToken: result['token']!,
          userId: result['userId']!,
        ),
      );
    } catch (e) {
      log(e.toString());
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    emit(AuthUnauthenticated());
  }

  // Helper for other Cubits/UI to get Dio client
  Dio? getClient() {
    if (state is AuthAuthenticated) {
      final s = state as AuthAuthenticated;
      return _authService.getClient(s.serverUrl, s.accessToken);
    }
    return null;
  }
}
