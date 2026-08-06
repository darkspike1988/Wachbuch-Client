import 'dart:async';

import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Offline service for caching API responses and enabling offline functionality.
///
/// This service uses Hive for local storage to cache API responses, allowing the app
/// to display cached data when offline. The cache is automatically invalidated when
/// new data is fetched from the server.
///
/// Usage:
/// ```dart
/// final offlineService = OfflineService();
/// await offlineService.init();
/// 
/// // Cache data
/// await offlineService.cacheHandovers(handovers);
/// 
/// // Get cached data
/// final cachedHandovers = offlineService.getCachedHandovers();
/// ```
class OfflineService {
  /// Box names for different data types
  static const String _handoversBox = 'handovers';
  static const String _calendarBox = 'calendar';
  static const String _coffeeBox = 'coffee';
  static const String _checklistsBox = 'checklists';
  static const String _settingsBox = 'settings';
  
  /// Cache duration in milliseconds (1 hour)
  static const Duration _cacheDuration = Duration(hours: 1);
  
  /// Whether the service is initialized
  bool _isInitialized = false;
  
  /// Initialize Hive and open boxes
  Future<void> init() async {
    if (_isInitialized) return;
    
    await Hive.initFlutter();
    
    // Register adapters if needed
    // Hive.registerAdapter(HandoverAdapter());
    // Hive.registerAdapter(CalendarEventAdapter());
    
    // Open boxes
    await Hive.openBox<dynamic>(_handoversBox);
    await Hive.openBox<dynamic>(_calendarBox);
    await Hive.openBox<dynamic>(_coffeeBox);
    await Hive.openBox<dynamic>(_checklistsBox);
    await Hive.openBox<dynamic>(_settingsBox);
    
    _isInitialized = true;
  }
  
  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Close all boxes
  Future<void> close() async {
    await Hive.close();
    _isInitialized = false;
  }
  
  /// Clear all cached data
  Future<void> clearAll() async {
    if (!_isInitialized) return;
    
    await Hive.box(_handoversBox).clear();
    await Hive.box(_calendarBox).clear();
    await Hive.box(_coffeeBox).clear();
    await Hive.box(_checklistsBox).clear();
    await Hive.box(_settingsBox).clear();
  }
  
  // ==================== Handover Cache ====================
  
  /// Cache handover list
  Future<void> cacheHandovers(List<dynamic> handovers) async {
    if (!_isInitialized) await init();
    
    final box = Hive.box(_handoversBox);
    await box.clear();
    
    // Store each handover with timestamp
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'handovers': handovers,
      'timestamp': now,
    };
    
    await box.put('handovers', data);
  }
  
  /// Get cached handovers
  List<dynamic>? getCachedHandovers() {
    if (!_isInitialized) return null;
    
    final box = Hive.box(_handoversBox);
    final data = box.get('handovers');
    
    if (data == null) return null;
    
    // Check if cache is expired
    final timestamp = data['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (now - timestamp > _cacheDuration.inMilliseconds) {
      return null; // Cache expired
    }
    
    return data['handovers'] as List<dynamic>?;
  }
  
  /// Check if handovers cache is valid
  bool hasValidHandoversCache() {
    if (!_isInitialized) return false;
    
    final box = Hive.box(_handoversBox);
    final data = box.get('handovers');
    
    if (data == null) return false;
    
    final timestamp = data['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    return now - timestamp <= _cacheDuration.inMilliseconds;
  }
  
  // ==================== Calendar Cache ====================
  
  /// Cache calendar events
  Future<void> cacheCalendarEvents(List<dynamic> events) async {
    if (!_isInitialized) await init();
    
    final box = Hive.box(_calendarBox);
    await box.clear();
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'events': events,
      'timestamp': now,
    };
    
    await box.put('events', data);
  }
  
  /// Get cached calendar events
  List<dynamic>? getCachedCalendarEvents() {
    if (!_isInitialized) return null;
    
    final box = Hive.box(_calendarBox);
    final data = box.get('events');
    
    if (data == null) return null;
    
    final timestamp = data['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (now - timestamp > _cacheDuration.inMilliseconds) {
      return null;
    }
    
    return data['events'] as List<dynamic>?;
  }
  
  // ==================== Coffee Cache ====================
  
  /// Cache coffee entries
  Future<void> cacheCoffeeEntries(List<dynamic> entries) async {
    if (!_isInitialized) await init();
    
    final box = Hive.box(_coffeeBox);
    await box.clear();
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'entries': entries,
      'timestamp': now,
    };
    
    await box.put('entries', data);
  }
  
  /// Get cached coffee entries
  List<dynamic>? getCachedCoffeeEntries() {
    if (!_isInitialized) return null;
    
    final box = Hive.box(_coffeeBox);
    final data = box.get('entries');
    
    if (data == null) return null;
    
    final timestamp = data['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (now - timestamp > _cacheDuration.inMilliseconds) {
      return null;
    }
    
    return data['entries'] as List<dynamic>?;
  }
  
  // ==================== Checklists Cache ====================
  
  /// Cache checklists
  Future<void> cacheChecklists(List<dynamic> checklists) async {
    if (!_isInitialized) await init();
    
    final box = Hive.box(_checklistsBox);
    await box.clear();
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = {
      'checklists': checklists,
      'timestamp': now,
    };
    
    await box.put('checklists', data);
  }
  
  /// Get cached checklists
  List<dynamic>? getCachedChecklists() {
    if (!_isInitialized) return null;
    
    final box = Hive.box(_checklistsBox);
    final data = box.get('checklists');
    
    if (data == null) return null;
    
    final timestamp = data['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    if (now - timestamp > _cacheDuration.inMilliseconds) {
      return null;
    }
    
    return data['checklists'] as List<dynamic>?;
  }
  
  // ==================== Settings Cache ====================
  
  /// Save a setting
  Future<void> saveSetting(String key, dynamic value) async {
    if (!_isInitialized) await init();
    
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }
  
  /// Get a setting
  dynamic getSetting(String key) {
    if (!_isInitialized) return null;
    
    final box = Hive.box(_settingsBox);
    return box.get(key);
  }
  
  /// Delete a setting
  Future<void> deleteSetting(String key) async {
    if (!_isInitialized) return;
    
    final box = Hive.box(_settingsBox);
    await box.delete(key);
  }
}

/// Singleton accessor
final offlineService = OfflineService();
