import 'package:wachbuch_mobile/screens/account_tab.dart';
import 'package:wachbuch_mobile/screens/handovers_tab.dart';
import 'package:wachbuch_mobile/screens/overview_tab.dart';
import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/demo/demo_api.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/l10n/generated/app_localizations.dart';
import 'package:wachbuch_mobile/services/connectivity_service.dart';
import 'package:wachbuch_mobile/state/auth_state.dart';
import 'package:wachbuch_mobile/state/handover_state.dart';
import 'package:wachbuch_mobile/ui/demo_banner.dart';
import 'package:wachbuch_mobile/ui/layout.dart';
import 'package:wachbuch_mobile/ui/offline_banner.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.api,
    required this.onLogout,
    required this.onChangeServer,
  });

  final WachbuchApi api;
  final Future<void> Function() onLogout;
  final Future<void> Function() onChangeServer;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  int _reloadGeneration = 0;
  late final HandoverState _handoverState;
  late final AuthState _authState;
  late final ConnectivityService _connectivity;
  late final Listenable _listenable;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _handoverState = HandoverState(api: widget.api);
    _authState = AuthState(api: widget.api);
    _connectivity = ConnectivityService();
    _listenable = Listenable.merge([_handoverState, _authState, _connectivity]);
    _connectivity.start();
    _connectivity.addListener(_onConnectivityChanged);
    _reload();
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _wasOffline && mounted) {
      _wasOffline = false;
      _reload();
    } else if (_connectivity.isOffline) {
      _wasOffline = true;
    }
  }

  Future<void> _reload() async {
    final generation = ++_reloadGeneration;
    await Future.wait([_authState.reload(), _handoverState.reload()]);
    if (!mounted || generation != _reloadGeneration) {
      return;
    }
    final isUnauthorized =
        _authState.lastError?.statusCode == 401 ||
        _handoverState.lastError?.statusCode == 401;
    if (isUnauthorized) {
      await widget.onLogout();
    }
  }

  bool get _loading => _authState.loading || _handoverState.loading;

  bool get _offline =>
      !_connectivity.isOnline ||
      _authState.lastError?.statusCode == 0 ||
      _handoverState.lastError?.statusCode == 0;

  bool get _isDemo =>
      widget.api is DemoWachbuchApi ||
      DemoService.isDemoUrl(widget.api.baseUrl);

  String? _demoServiceLabel(AppLocalizations l10n) {
    final service = widget.api is DemoWachbuchApi
        ? (widget.api as DemoWachbuchApi).profile.service
        : DemoService.fromServerUrl(widget.api.baseUrl);
    return switch (service) {
      DemoService.rettungsdienst => l10n.demoBannerRettungsdienst,
      DemoService.feuerwehr => l10n.demoBannerFeuerwehr,
      DemoService.ffw => l10n.demoBannerFfw,
      DemoService.polizei => l10n.demoBannerPolizei,
      null => null,
    };
  }

  String? _displayError(AppLocalizations l10n) {
    for (final error in [_authState.lastError, _handoverState.lastError]) {
      if (error == null) continue;
      if (error.statusCode == 401) return l10n.sessionExpiredError;
      return error.message;
    }
    return _authState.error ?? _handoverState.error;
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    _connectivity.dispose();
    _handoverState.dispose();
    _authState.dispose();
    widget.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final tablet = AppLayout.isTablet(width);

    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) {
        final stationName = _authState.stationName(l.stationFallback);
        final error = _displayError(l);
        final loading = _loading;
        final offline = _offline;

        final pages = IndexedStack(
          index: _tab,
          children: [
            OverviewTab(
              api: widget.api,
              stationName: stationName,
              roleLabel: _authState.roleLabel,
              modules: _authState.modules,
              handovers: _handoverState.items,
              loading: loading,
              hasData: _authState.hasData,
              error: error,
              onRefresh: _reload,
            ),
            HandoversTab(
              api: widget.api,
              handoverState: _handoverState,
              currentUsername: _authState.username,
              error: error,
              onRefresh: _reload,
            ),
            AccountTab(
              me: _authState.me,
              serverUrl: widget.api.baseUrl,
              loading: loading,
              onLogout: widget.onLogout,
              onChangeServer: widget.onChangeServer,
              onRefresh: _reload,
            ),
          ],
        );

        final appBar = AppBar(
          title: Text(
            stationName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: l.refreshTooltip,
              onPressed: loading ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        );

        final offlineBanner = OfflineBanner(
          visible: offline && !_isDemo,
          onRetry: loading ? () {} : _reload,
        );
        final demoBanner = DemoBanner(
          visible: _isDemo,
          label: l.demoBannerLabel,
          serviceLabel: _demoServiceLabel(l),
        );

        if (tablet) {
          return Scaffold(
            appBar: appBar,
            body: Column(
              children: [
                demoBanner,
                offlineBanner,
                Expanded(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _tab,
                        onDestinationSelected: (index) =>
                            setState(() => _tab = index),
                        labelType: width >= AppLayout.wideBreakpoint
                            ? NavigationRailLabelType.all
                            : NavigationRailLabelType.selected,
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.home_outlined),
                            selectedIcon: const Icon(Icons.home),
                            label: Text(l.navOverview),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.assignment_outlined),
                            selectedIcon: const Icon(Icons.assignment),
                            label: Text(l.navHandovers),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.person_outline),
                            selectedIcon: const Icon(Icons.person),
                            label: Text(l.navAccount),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: pages),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: Column(
            children: [
              demoBanner,
              offlineBanner,
              Expanded(child: pages),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                label: l.navOverview,
              ),
              NavigationDestination(
                icon: const Icon(Icons.assignment_outlined),
                label: l.navHandovers,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                label: l.navAccount,
              ),
            ],
          ),
        );
      },
    );
  }
}
