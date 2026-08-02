import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/api/server_address.dart';
import 'package:wachbuch_mobile/api/server_links.dart';
import 'package:wachbuch_mobile/auth/session_store.dart';
import 'package:wachbuch_mobile/screens/home_shell.dart';
import 'package:wachbuch_mobile/screens/login_screen.dart';
import 'package:wachbuch_mobile/screens/server_setup_screen.dart';
import 'package:wachbuch_mobile/theme/solar_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SessionStore();
  final links = AppLinksServerLinkSource();
  final themeController = SolarThemeController.device();
  runApp(
    WachbuchApp(
      store: store,
      linkSource: links,
      themeController: themeController,
    ),
  );
}

enum _BootPhase { booting, setupServer, login, home }

class WachbuchApp extends StatefulWidget {
  const WachbuchApp({
    super.key,
    required this.store,
    this.linkSource = const NoopServerLinkSource(),
    this.themeController,
  });

  final SessionStore store;
  final ServerLinkSource linkSource;
  final SolarThemeController? themeController;

  @override
  State<WachbuchApp> createState() => _WachbuchAppState();
}

class _WachbuchAppState extends State<WachbuchApp> with WidgetsBindingObserver {
  _BootPhase _phase = _BootPhase.booting;
  String? _serverUrl;
  WachbuchApi? _api;
  StreamSubscription<Uri>? _linkSubscription;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    final themeController = widget.themeController;
    if (themeController != null) {
      _themeMode = themeController.mode;
      themeController.addListener(_handleThemeChange);
      WidgetsBinding.instance.addObserver(this);
      unawaited(themeController.refresh());
    }
    _bootstrap();
  }

  void _handleThemeChange() {
    if (!mounted) return;
    setState(() {
      _themeMode = widget.themeController?.mode ?? ThemeMode.system;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = widget.themeController;
      if (controller != null) unawaited(controller.refresh());
    }
  }

  Future<void> _bootstrap() async {
    var url = await widget.store.readServerUrl();
    var token = await widget.store.readToken();

    final initialLink = await widget.linkSource.getInitialLink();
    if (initialLink != null) {
      final linkedUrl = _parseLink(initialLink);
      if (linkedUrl != null) {
        await widget.store.clearAll();
        await widget.store.writeServerUrl(linkedUrl);
        url = linkedUrl;
        token = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _serverUrl = url;
      if (url != null && url.isNotEmpty && token != null && token.isNotEmpty) {
        _api = WachbuchApi(baseUrl: url, token: token);
        _phase = _BootPhase.home;
      } else if (url != null && url.isNotEmpty) {
        _phase = _BootPhase.login;
      } else {
        _phase = _BootPhase.setupServer;
      }
    });

    _linkSubscription = widget.linkSource.uriLinkStream.listen(
      _handleServerLink,
      onError: (_) {},
    );
  }

  String? _parseLink(Uri link) {
    try {
      return parseServerAddress(link.toString());
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _handleServerLink(Uri link) async {
    final url = _parseLink(link);
    if (url == null) return;
    await widget.store.clearAll();
    await widget.store.writeServerUrl(url);
    if (!mounted) return;
    setState(() {
      _api = null;
      _serverUrl = url;
      _phase = _BootPhase.login;
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    final themeController = widget.themeController;
    if (themeController != null) {
      WidgetsBinding.instance.removeObserver(this);
      themeController.removeListener(_handleThemeChange);
      themeController.dispose();
    }
    super.dispose();
  }

  Future<void> _onServerReady(String url) async {
    await widget.store.writeServerUrl(url);
    if (!mounted) return;
    setState(() {
      _serverUrl = url;
      _phase = _BootPhase.login;
    });
  }

  Future<void> _onLoggedIn(String url, String token) async {
    await widget.store.writeServerUrl(url);
    await widget.store.writeToken(token);
    if (!mounted) return;
    setState(() {
      _serverUrl = url;
      _api = WachbuchApi(baseUrl: url, token: token);
      _phase = _BootPhase.home;
    });
  }

  Future<void> _logout() async {
    await widget.store.clearToken();
    if (!mounted) return;
    setState(() {
      _api = null;
      _phase = _serverUrl == null || _serverUrl!.isEmpty
          ? _BootPhase.setupServer
          : _BootPhase.login;
    });
  }

  Future<void> _changeServer() async {
    await widget.store.clearAll();
    if (!mounted) return;
    setState(() {
      _api = null;
      _serverUrl = null;
      _phase = _BootPhase.setupServer;
    });
  }

  ThemeData _theme(Brightness brightness) {
    const seed = Color(0xFF1F4D3A);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        indicatorColor: scheme.secondaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    switch (_phase) {
      case _BootPhase.booting:
        home = const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _BootPhase.setupServer:
        home = ServerSetupScreen(
          store: widget.store,
          onServerReady: _onServerReady,
        );
      case _BootPhase.login:
        home = LoginScreen(
          store: widget.store,
          serverUrl: _serverUrl!,
          onLoggedIn: _onLoggedIn,
          onChangeServer: _changeServer,
        );
      case _BootPhase.home:
        home = HomeShell(
          api: _api!,
          onLogout: _logout,
          onChangeServer: _changeServer,
        );
    }

    return MaterialApp(
      title: 'Wachbuch',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: home,
    );
  }
}
