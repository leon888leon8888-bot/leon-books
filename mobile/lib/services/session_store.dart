import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models/app_models.dart';

class SessionStore {
  final ValueNotifier<SessionState> state = ValueNotifier(SessionState.empty);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString('baseUrl') ?? '';
    final savedToken = prefs.getString('token') ?? '';
    final hasBundledConfig = AppConfig.apiToken.isNotEmpty;
    final baseUrl = hasBundledConfig
        ? AppConfig.apiBaseUrl
        : (savedBaseUrl.isNotEmpty ? savedBaseUrl : SessionState.empty.baseUrl);
    final token = hasBundledConfig ? AppConfig.apiToken : savedToken;
    final userId = prefs.getString('userId');
    final email = prefs.getString('email');
    final displayName = prefs.getString('displayName');
    final membershipTier = prefs.getString('membershipTier');

    state.value = SessionState(
      baseUrl: baseUrl,
      token: token,
      user: userId == null || email == null || displayName == null
          ? null
          : ReaderUser(
              id: userId,
              email: email,
              displayName: displayName,
              membershipTier: membershipTier ?? 'founder',
            ),
    );
  }

  Future<void> saveOwnerSession({
    required String baseUrl,
    String token = '',
    required ReaderUser user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', baseUrl);
    await prefs.setString('token', token);
    await prefs.setString('userId', user.id);
    await prefs.setString('email', user.email);
    await prefs.setString('displayName', user.displayName);
    await prefs.setString('membershipTier', user.membershipTier);

    state.value = SessionState(
      baseUrl: baseUrl,
      token: token,
      user: user,
    );
  }

  Future<void> saveBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', baseUrl);
    state.value = state.value.copyWith(baseUrl: baseUrl);
  }

  Future<void> resetSetup({bool keepBaseUrl = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = AppConfig.apiToken.isNotEmpty
        ? AppConfig.apiBaseUrl
        : keepBaseUrl
        ? (prefs.getString('baseUrl') ?? SessionState.empty.baseUrl)
        : SessionState.empty.baseUrl;
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('email');
    await prefs.remove('displayName');
    await prefs.remove('membershipTier');
    if (!keepBaseUrl) {
      await prefs.remove('baseUrl');
    }
    state.value = SessionState(
      baseUrl: baseUrl,
      token: AppConfig.apiToken.isNotEmpty ? AppConfig.apiToken : '',
      user: null,
    );
  }
}
