/// Offline [WachbuchApi] backed by [DemoProfile] sample data.
library;

import 'package:http/http.dart' as http;
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/demo/demo_profiles.dart';
import 'package:wachbuch_mobile/models/checkliste.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';
import 'package:wachbuch_mobile/models/inventory_item.dart';
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
    List<StationAsset>? assets,
    List<InventoryItem>? inventory,
    Map<int, List<HandoverAck>>? acks,
  })  : _defects = List<Defect>.from(defects ?? profile.defects),
        _assets = List<StationAsset>.from(assets ?? profile.assets),
        _inventory = List<InventoryItem>.from(inventory ?? profile.inventory),
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
  final List<StationAsset> _assets;
  final List<InventoryItem> _inventory;
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
  Future<Defect> createDefect(Map<String, dynamic> payload) async {
    final nextId = _defects.fold<int>(
          0,
          (max, defect) => defect.id > max ? defect.id : max,
        ) +
        1;
    final created = Defect.fromJson({
      ...payload,
      'id': nextId,
      'owner': payload['owner'] ?? profile.username,
    });
    _defects.insert(0, created);
    return created;
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
  Future<List<DefectAttachment>> defectAttachments(int id) async {
    final index = _defects.indexWhere((defect) => defect.id == id);
    if (index < 0) {
      throw ApiException(404, 'Mangel nicht gefunden.');
    }
    return List<DefectAttachment>.unmodifiable(_defects[index].attachments);
  }

  @override
  Future<DefectAttachment> addDefectAttachment(
    int id, {
    required String name,
    String contentType = 'image/jpeg',
    int sizeBytes = 0,
  }) async {
    final index = _defects.indexWhere((defect) => defect.id == id);
    if (index < 0) {
      throw ApiException(404, 'Mangel nicht gefunden.');
    }
    final existing = _defects[index];
    final attachment = DefectAttachment(
      id: 'att-${id}-${existing.attachments.length + 1}',
      name: name.trim().isEmpty ? 'beleg-demo.jpg' : name.trim(),
      contentType: contentType,
      sizeBytes: sizeBytes > 0 ? sizeBytes : 12 * 1024,
      createdAt: DateTime.now(),
      localOnly: true,
    );
    _defects[index] = existing.copyWith(
      attachments: [...existing.attachments, attachment],
    );
    return attachment;
  }

  @override
  Future<List<StationAsset>> assets() async {
    return List<StationAsset>.unmodifiable(_assets);
  }

  @override
  Future<StationAsset> updateAssetStatus(
    String id, {
    required String status,
    String note = '',
  }) async {
    final index = _assets.indexWhere((asset) => asset.id == id);
    if (index < 0) {
      throw ApiException(404, 'Gerät nicht gefunden.');
    }
    final updated = StationAsset.fromJson({
      ..._assets[index].toJson(),
      'status': status,
      if (note.isNotEmpty) 'note': note,
    });
    _assets[index] = updated;
    return updated;
  }

  @override
  Future<List<InventoryItem>> inventory() async {
    return List<InventoryItem>.unmodifiable(_inventory);
  }

  @override
  Future<InventoryItem> inventoryCheckout(String id) async {
    final index = _inventory.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw ApiException(404, 'Inventar nicht gefunden.');
    }
    final updated = _inventory[index].copyWith(
      holder: profile.username,
      since: DateTime.now(),
      sinceLabel: 'gerade eben',
    );
    _inventory[index] = updated;
    return updated;
  }

  @override
  Future<InventoryItem> inventoryCheckin(String id) async {
    final index = _inventory.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw ApiException(404, 'Inventar nicht gefunden.');
    }
    final updated = _inventory[index].copyWith(clearHolder: true);
    _inventory[index] = updated;
    return updated;
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
      assets: _assets,
      inventory: _inventory,
      acks: _acks,
    );
  }

  @override
  void close() {
    // Noop client — nothing to close.
  }
}
