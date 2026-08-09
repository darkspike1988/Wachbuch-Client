import 'package:flutter_test/flutter_test.dart';
import 'package:wachbuch_mobile/api/wachalltag_paths.dart';

void main() {
  test('WachalltagPaths match OpenAPI contract freeze', () {
    expect(WachalltagPaths.defects, '/api/v1/defects/');
    expect(WachalltagPaths.defectDetail(9), '/api/v1/defects/9/');
    expect(WachalltagPaths.defectStatus(9), '/api/v1/defects/9/status/');
    expect(WachalltagPaths.assets, '/api/v1/assets/');
    expect(WachalltagPaths.assetStatus('rtw-1'), '/api/v1/assets/rtw-1/status/');
    expect(WachalltagPaths.handoverAcks(3), '/api/v1/handovers/3/acks/');
    expect(WachalltagPaths.handoverAck(3), '/api/v1/handovers/3/ack/');
    expect(WachalltagPaths.inventory, '/api/v1/inventory/');
    expect(
      WachalltagPaths.inventoryCheckout('funk-a'),
      '/api/v1/inventory/funk-a/checkout/',
    );
    expect(
      WachalltagPaths.inventoryCheckin('funk-a'),
      '/api/v1/inventory/funk-a/checkin/',
    );
    expect(WachalltagPaths.moduleDefects, 'defects');
    expect(WachalltagPaths.moduleAssets, 'assets');
    expect(WachalltagPaths.moduleInventory, 'inventory');
  });
}
