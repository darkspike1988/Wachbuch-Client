/// Offline [WachbuchApi] backed by [DemoProfile] sample data.
library;

import 'package:http/http.dart' as http;
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/kaffeekasse.dart';
import 'package:wachbuch_mobile/models/kalender_entry.dart';

const demoTokenPrefix = 'wb_demo_';

/// Returns a demo API when [baseUrl] matches a [DemoService] host.
WachbuchApi createWachbuchApi(String baseUrl, {String? token}) {
  final service = DemoService.fromServerUrl(baseUrl);
  if (service != null) {
    return DemoWachbuchApi(
      profile: demoProfileFor(service),
      token: token ?? '$demoTokenPrefix${service.id}',
    );
  }
  return WachbuchApi(baseUrl: baseUrl, token: token);
}

/// Drop-in [WachbuchApiFactory] that routes demo hosts to [DemoWachbuchApi].
WachbuchApi demoAwareApiFactory(String baseUrl) => createWachbuchApi(baseUrl);

class _NoopClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw UnsupportedError('Demo API performs no network I/O.');
  }
}

class DemoWachbuchApi extends WachbuchApi {
  DemoWachbuchApi({
    required this.profile,
    String? token,
  }) : super(
          baseUrl: profile.service.serverUrl,
          token: token ?? '$demoTokenPrefix${profile.service.id}',
          client: _NoopClient(),
        );

  final DemoProfile profile;
  final Set<int> _completedChecklists = {};

  bool get isDemo => true;

  @override
  Future<Map<String, dynamic>> discover() async {
    return {
      'ok': true,
      'api_version': 'v1',
      'name': 'Wachbuch Demo',
      'demo': true,
      'service': profile.service.id,
      'endpoints': {
        'token': '/api/v1/token/',
        'me': '/api/v1/me/',
        'handovers': '/api/v1/handovers/',
      },
    };
  }

  @override
  Future<AuthToken> obtainToken({
    required String username,
    required String password,
    String label = 'Mobile App',
  }) async {
    return AuthToken(
      value: '$demoTokenPrefix${profile.service.id}',
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  @override
  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(profile.me);

  @override
  Future<List<Map<String, dynamic>>> handovers() async {
    return profile.handovers
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> handoverDetail(int id) async {
    for (final entry in profile.handovers) {
      if (entry['id'] == id) {
        return Map<String, dynamic>.from(entry);
      }
    }
    throw ApiException(404, 'Übergabe nicht gefunden.');
  }

  @override
  Future<List<KalenderEntry>> kalender() async {
    return profile.calendar
        .map(KalenderEntry.fromJson)
        .toList(growable: false);
  }

  @override
  Future<Kaffeekasse> kaffeekasse() async {
    return Kaffeekasse.fromJson(Map<String, dynamic>.from(profile.coffee));
  }

  @override
  Future<List<Checklist>> checklisten() async {
    return profile.checklists.map((raw) {
      final id = raw['id'] as int? ?? 0;
      final completed = _completedChecklists.contains(id) || raw['completed'] == true;
      return Checklist.fromJson({...raw, 'completed': completed});
    }).toList(growable: false);
  }

  @override
  Future<Checklist> checklisteAbschluss(int id) async {
    _completedChecklists.add(id);
    final match = profile.checklists.cast<Map<String, dynamic>?>().firstWhere(
          (entry) => entry?['id'] == id,
          orElse: () => null,
        );
    if (match == null) {
      return Checklist(id: id, title: '', completed: true);
    }
    return Checklist.fromJson({...match, 'completed': true});
  }

  @override
  DemoWachbuchApi copyWithToken(String newToken) {
    return DemoWachbuchApi(profile: profile, token: newToken);
  }

  @override
  void close() {
    // Noop client — nothing to close.
  }
}
