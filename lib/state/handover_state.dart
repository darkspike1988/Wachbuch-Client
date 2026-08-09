import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/services/offline_read_cache.dart';
import 'package:wachbuch_mobile/ui/handover_filter.dart';

class HandoverState extends ChangeNotifier {
  HandoverState({required this.api, this.cache});

  final WachbuchApi api;
  final OfflineReadCache? cache;

  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String? _error;
  ApiException? _lastError;
  bool _fromCache = false;
  DateTime? _cacheUpdatedAt;
  String _searchQuery = '';
  final Set<String> _statuses = {};
  final Set<String> _priorities = {};
  bool _disposed = false;

  UnmodifiableListView<Map<String, dynamic>> get items =>
      UnmodifiableListView(_items);
  bool get loading => _loading;
  String? get error => _error;
  ApiException? get lastError => _lastError;
  bool get fromCache => _fromCache;
  DateTime? get cacheUpdatedAt => _cacheUpdatedAt;
  String get searchQuery => _searchQuery;
  Set<String> get statuses => Set.unmodifiable(_statuses);
  Set<String> get priorities => Set.unmodifiable(_priorities);

  List<Map<String, dynamic>> get filteredItems => filterHandovers(
        _items,
        query: _searchQuery,
        statuses: _statuses,
        priorities: _priorities,
      );

  Future<void> reload() async {
    _loading = true;
    _error = null;
    _lastError = null;
    _notify();
    try {
      _items = await api.handovers();
      _fromCache = false;
      _cacheUpdatedAt = DateTime.now();
      // Ignore future: secure storage must not block reload / widget tests.
      cache?.write(handovers: _items, updatedAt: _cacheUpdatedAt);
    } on ApiException catch (error) {
      _lastError = error;
      _error = error.message;
      await _tryLoadCache();
    } catch (error) {
      _error = error.toString();
      await _tryLoadCache();
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _tryLoadCache() async {
    final snapshot = await cache?.read();
    if (snapshot == null || snapshot.handovers.isEmpty) return;
    _items = List<Map<String, dynamic>>.from(snapshot.handovers);
    _fromCache = true;
    _cacheUpdatedAt = snapshot.updatedAt;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _notify();
  }

  void toggleStatus(String value, {required bool selected}) {
    selected ? _statuses.add(value) : _statuses.remove(value);
    _notify();
  }

  void togglePriority(String value, {required bool selected}) {
    selected ? _priorities.add(value) : _priorities.remove(value);
    _notify();
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
