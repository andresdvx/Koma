import 'package:koma_source_api/koma_source_api.dart';

import 'source_client_contract.dart';

void main() {
  sourceClientContract('FakeSourceClient', FakeSourceClient.new,
      sourceId: '1001');
}
