import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pages/home_shell.dart';
import 'pages/setup_page.dart';
import 'services/api_client.dart';
import 'services/session_store.dart';

class ReaderRebuildApp extends StatefulWidget {
  const ReaderRebuildApp({super.key});

  @override
  State<ReaderRebuildApp> createState() => _ReaderRebuildAppState();
}

class _ReaderRebuildAppState extends State<ReaderRebuildApp> {
  final SessionStore _sessionStore = SessionStore();
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _sessionStore.load();
    await _autoConnect();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoaded = true;
    });
  }

  Future<void> _autoConnect() async {
    final session = _sessionStore.state.value;
    if (session.isReady || session.token.isEmpty) {
      return;
    }
    try {
      final client = ApiClient(baseUrl: session.baseUrl, token: session.token);
      final user = await client.getMe();
      await _sessionStore.saveOwnerSession(
        baseUrl: session.baseUrl,
        token: session.token,
        user: user,
      );
    } catch (_) {
      // Fall back to the setup page if the bundled server configuration fails.
    }
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFF0A84FF);
    return ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.iOS,
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      splashFactory: NoSplash.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      cupertinoOverrideTheme: const NoDefaultCupertinoThemeData(
        primaryColor: seed,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        barBackgroundColor: CupertinoColors.systemBackground,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        filled: true,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leon的书',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final topPadding = defaultTargetPlatform == TargetPlatform.iOS ? 8.0 : 0.0;
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.2),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: !_isLoaded
          ? const Scaffold(body: Center(child: CupertinoActivityIndicator()))
          : ValueListenableBuilder(
              valueListenable: _sessionStore.state,
              builder: (context, session, _) {
                if (!session.isReady) {
                  return SetupPage(sessionStore: _sessionStore);
                }
                return HomeShell(sessionStore: _sessionStore);
              },
            ),
    );
  }
}
