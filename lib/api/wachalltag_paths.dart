/// Stable `/api/v1/` paths for Wachalltag modules.
///
/// Keep in sync with `docs/openapi-wachalltag.yaml` (Welle 2 Contract Freeze).
library;

abstract final class WachalltagPaths {
  static const apiPrefix = '/api/v1';

  static const defects = '$apiPrefix/defects/';
  static String defectDetail(int id) => '$apiPrefix/defects/$id/';
  static String defectStatus(int id) => '$apiPrefix/defects/$id/status/';

  static const assets = '$apiPrefix/assets/';
  static String assetStatus(String id) => '$apiPrefix/assets/$id/status/';

  static String handoverAcks(int id) => '$apiPrefix/handovers/$id/acks/';
  static String handoverAck(int id) => '$apiPrefix/handovers/$id/ack/';

  static const inventory = '$apiPrefix/inventory/';
  static String inventoryCheckout(String id) =>
      '$apiPrefix/inventory/$id/checkout/';
  static String inventoryCheckin(String id) =>
      '$apiPrefix/inventory/$id/checkin/';

  /// Module keys under `GET /me/` → `membership.station.modules`.
  static const moduleDefects = 'defects';
  static const moduleAssets = 'assets';
  static const moduleInventory = 'inventory';
}
