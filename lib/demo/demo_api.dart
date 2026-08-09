/// Offline [WachbuchApi] backed by [DemoProfile] sample data.
library;

import 'package:http/http.dart' as http;
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';
import 'package:wachbuch_mobile/models/kaffeekasse.dart';
import 'package:wachbuch_mobile/models/kalender_entry.dart';
import 'package:wachbuch_mobile/models/station_asset.dart';

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
    List<Defect>? defects,
    Map<int, List<HandoverAck>>? acks,
  })  : _defects = List<Defect>.from(defects ?? profile.defects),
        _acks = {
          for (final entry in (acks ?? const <int, List<HandoverAck>>{}).entries)
            entry.key: List<HandoverAck>.from(entry.value),
        },
        super(
          baseUrl: profile.service.serverUrl,
          token: token ?? '$demoTokenPrefix${profile.service.id}',
          client: _NoopClient(),
        );

  final DemoProfile profile;
  final Set<int> _completedChecklists = {};
  final List<Defect> _defects;
  final Map<int, List<HandoverAck>> _acks;

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
        'defects': '/api/v1/defects/',
        'assets': '/api/v1/assets/',
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
  Future<List<Defect>> defects() async {
    return List<Defect>.unmodifiable(_defects);
  }

  @override
  Future<Defect> updateDefectStatus(int id, String status) async {
    final index = _defects.indexWhere((defect) => defect.id == id);
    if (index < 0) {
      throw ApiException(404, 'Mangel nicht gefunden.');
    }
    // Re-parse so aliases like "blocked"/"closed" stay on the contract enums.
    final updated = Defect.fromJson({
      ..._defects[index].toJson(),
      'status': status,
    });
    _defects[index] = updated;
    return updated;
  }

  @override
  Future<List<StationAsset>> assets() async {
    return List<StationAsset>.unmodifiable(profile.assets);
  }

  @override
  Future<List<HandoverAck>> handoverAcks(int id) async {
    return List<HandoverAck>.unmodifiable(_acks[id] ?? const []);
  }

  @override
  Future<HandoverAck> acknowledgeHandover(int id) async {
    final exists = profile.handovers.any((entry) => entry['id'] == id);
    if (!exists) {
      throw ApiException(404, 'Übergabe nicht gefunden.');
    }
    final by = profile.username;
    final current = _acks.putIfAbsent(id, () => <HandoverAck>[]);
    final existing = current.where((ack) => ack.by == by);
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final ack = HandoverAck(handoverId: id, by: by, at: DateTime.now());
    current.add(ack);
    return ack;
  }

  @override
  DemoWachbuchApi copyWithToken(String newToken) {
    return DemoWachbuchApi(
      profile: profile,
      token: newToken,
      defects: _defects,
      acks: _acks,
    );
  }

  @override
  void close() {
    // Noop client — nothing to close.
  }
}
