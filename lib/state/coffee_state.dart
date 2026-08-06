import 'package:flutter/foundation.dart';
import '../api/client.dart';
import '../models/kaffeekasse.dart';

class CoffeeState extends ChangeNotifier {
  CoffeeState({required this.api});

  final WachbuchApi api;

  bool _disposed = false;
  Kaffeekasse? _data;
  bool _loading = false;
  String? _error;

  Kaffeekasse? get data => _data;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> reload() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      _data = await api.kaffeekasse();
    } catch (e) {
      _error = 'Kaffeekasse nicht erreichbar: $e';
    } finally {
      _loading = false;
      _notify();
    }
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
