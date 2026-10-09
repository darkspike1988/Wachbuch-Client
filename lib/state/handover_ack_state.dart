import 'package:flutter/foundation.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/models/handover_ack.dart';

enum HandoverAckFailure { stale, api, unexpected, invalidRevision }

/// Revision-bound receipt state. No widgets or translated strings belong here.
/// GET snapshots are append-only; an old response cannot erase a successful POST.
class HandoverAckState extends ChangeNotifier {
  HandoverAckState({required this.api, required this.handoverId});

  final WachbuchApi api;
  final int handoverId;
  List<HandoverAck> _receipts = const [];
  bool _disposed = false;
  int _loadGeneration = 0;

  List<HandoverAck> get receipts => List.unmodifiable(_receipts);
  bool _loading = false;
  bool _supported = true;
  bool _acknowledging = false;
  bool _loadFailed = false;
  String? _loadMessage;
  HandoverAckFailure? _failure;
  String? _failureMessage;

  bool get loading => _loading;
  bool get supported => _supported;
  bool get acknowledging => _acknowledging;
  bool get loadFailed => _loadFailed;
  String? get loadMessage => _loadMessage;
  HandoverAckFailure? get failure => _failure;
  String? get failureMessage => _failureMessage;

  bool acknowledgedBy(String? username, int? version) =>
      username != null &&
      version != null &&
      _receipts.any((ack) => ack.by == username && ack.version == version);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _loading = true;
    _loadFailed = false;
    _loadMessage = null;
    _changed();
    try {
      final snapshot = await api.handoverAcks(handoverId);
      if (_disposed || generation != _loadGeneration) return;
      if (snapshot.any((ack) => ack.handoverId != handoverId)) {
        throw StateError('Receipt does not belong to this handover');
      }
      _receipts = [
        ...snapshot,
        ..._receipts.where((ack) => !snapshot.contains(ack)),
      ];
      _supported = true;
    } on ApiException catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      if (WachbuchApi.isModuleUnavailable(error)) {
        _supported = false;
      } else {
        _loadFailed = true;
        _loadMessage = error.message;
      }
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
      // A temporary network _failure is NOT an unsupported server capability.
      _loadFailed = true;
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _loading = false;
        _changed();
      }
    }
  }

  Future<void> acknowledge(int version) async {
    if (_disposed || _acknowledging || !_supported) return;
    if (version < 1) {
      _failure = HandoverAckFailure.invalidRevision;
      _changed();
      return;
    }
    _acknowledging = true;
    _failure = null;
    _failureMessage = null;
    _changed();
    try {
      final ack = await api.acknowledgeHandover(handoverId, version: version);
      if (_disposed) return;
      if (ack.handoverId != handoverId || ack.version != version) {
        throw StateError('Receipt does not match the requested revision');
      }
      _receipts = [
        ..._receipts.where(
          (item) => !(item.by == ack.by && item.version == ack.version),
        ),
        ack,
      ];
    } on ApiException catch (error) {
      if (_disposed) return;
      _failure = error.statusCode == 409
          ? HandoverAckFailure.stale
          : HandoverAckFailure.api;
      _failureMessage = error.message;
    } catch (_) {
      if (_disposed) return;
      _failure = HandoverAckFailure.unexpected;
    } finally {
      if (!_disposed) {
        _acknowledging = false;
        _changed();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
