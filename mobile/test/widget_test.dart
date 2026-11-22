import 'package:flutter_test/flutter_test.dart';

import 'package:boru/services/boru_gift_service.dart';

void main() {
  group('BORU Gift Service', () {
    test('Hediye istek kimligi olusturulur', () {
      final requestId = BoruGiftService.createRequestId();

      expect(requestId, isNotEmpty);
      expect(requestId.length, greaterThanOrEqualTo(8));
      expect(RegExp(r'^[a-zA-Z0-9_-]{8,100}$').hasMatch(requestId), isTrue);
    });

    test('Her hediye istegi benzersiz kimlik alir', () {
      final ids = List.generate(100, (_) => BoruGiftService.createRequestId());

      expect(ids.toSet().length, 100);
    });
  });
}
