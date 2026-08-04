import 'package:flutter_test/flutter_test.dart';
import 'package:npo_community/core/services/exchange_service.dart';

void main() {
  test('ExchangeMetadata encodes and parses round-trip', () {
    final encoded = ExchangeMetadata.encode(
      kind: ExchangeKind.offer,
      compensation: ExchangeCompensation.paid,
      price: '\$25/hr',
      tags: const ['🧰', '🧹'],
    );

    final parsed = ExchangeMetadata.tryParse(encoded);

    expect(parsed, isNotNull);
    expect(parsed!.kind, ExchangeKind.offer);
    expect(parsed.compensation, ExchangeCompensation.paid);
    expect(parsed.price, '\$25/hr');
    expect(parsed.tags, ['🧰', '🧹']);
  });

  test('ExchangeMetadata parsing rejects non-exchange feelings', () {
    expect(ExchangeMetadata.tryParse('community'), isNull);
    expect(ExchangeMetadata.tryParse(''), isNull);
    expect(ExchangeMetadata.tryParse(null), isNull);
  });

  test('ExchangeMetadata parsing supports trade + no price', () {
    final encoded = ExchangeMetadata.encode(
      kind: ExchangeKind.request,
      compensation: ExchangeCompensation.trade,
      tags: const ['🪡'],
    );

    final parsed = ExchangeMetadata.tryParse(encoded);

    expect(parsed, isNotNull);
    expect(parsed!.kind, ExchangeKind.request);
    expect(parsed.compensation, ExchangeCompensation.trade);
    expect(parsed.price, isNull);
    expect(parsed.tags, ['🪡']);
  });
}
