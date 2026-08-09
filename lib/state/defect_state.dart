import 'package:flutter/foundation.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/defect.dart';
import 'package:wachbuch_mobile/models/defect_attachment.dart';
import 'package:wachbuch_mobile/services/offline_read_cache.dart';

/// Loads and updates station defects (Mängel).
class DefectState extends ChangeNotifier {
  DefectState({required this.api, this.cache});

  final WachbuchApi api;
  final OfflineReadCache? cache;

  List<Defect> _items = const [];
  bool _loading = false;
  String? _error;
  ApiException? _lastError;
  bool _fromCache = false;
  DateTime? _cacheUpdatedAt;
  bool _disposed = false;

  List<Defect> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  ApiException? get lastError => _lastError;
  bool get hasData => _items.isNotEmpty;
  bool get fromCache => _fromCache;
  DateTime? get cacheUpdatedAt => _cacheUpdatedAt;

  int get openCount => _items.where((item) => item.isOpen).length;

  int get urgentCount => _items.where((item) => item.isUrgent).length;

  Future<void> reload() async {
    _loading = true;
    _error = null;
    _lastError = null;
    _notify();
    try {
      _items = await api.defects();
      _fromCache = false;
      _cacheUpdatedAt = DateTime.now();
      cache?.write(defects: _items, updatedAt: _cacheUpdatedAt);
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      if (WachbuchApi.isModuleUnavailable(error)) {
        _items = const [];
        _fromCache = false;
      } else {
        await _tryLoadCache();
      }
    } catch (error) {
      _error = error.toString();
      await _tryLoadCache();
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<bool> create(Map<String, dynamic> payload) async {
    _error = null;
    _lastError = null;
    try {
      final created = await api.createDefect(payload);
      _items = [created, ..._items];
      _fromCache = false;
      cache?.write(defects: _items);
      _notify();
      return true;
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      _notify();
      return false;
    } catch (error) {
      _error = error.toString();
      _notify();
      return false;
    }
  }

  Future<bool> setStatus(int id, String status) async {
    _error = null;
    _lastError = null;
    try {
      final updated = await api.updateDefectStatus(id, status);
      _items = [
        for (final item in _items)
          if (item.id == id) updated else item,
      ];
      _fromCache = false;
      cache?.write(defects: _items);
      _notify();
      return true;
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      _notify();
      return false;
    } catch (error) {
      _error = error.toString();
      _notify();
      return false;
    }
  }

  Future<DefectAttachment?> addDemoAttachment(int id, {String? name}) async {
    _error = null;
    _lastError = null;
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final attachment = await api.addDefectAttachment(
        id,
        name: name ?? 'beleg-demo-$stamp.jpg',
        contentType: 'image/jpeg',
        sizeBytes: 12 * 1024,
      );
      _items = [
        for (final item in _items)
          if (item.id == id)
            item.copyWith(attachments: [...item.attachments, attachment])
          else
            item,
      ];
      _notify();
      return attachment;
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      _notify();
      return null;
    } catch (error) {
      _error = error.toString();
      _notify();
      return null;
    }
  }

  Future<void> _tryLoadCache() async {
    final snapshot = await cache?.read();
    if (snapshot == null || snapshot.defects.isEmpty) return;
    _items = snapshot.defects;
    _fromCache = true;
    _cacheUpdatedAt = snapshot.updatedAt;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
