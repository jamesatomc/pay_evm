import 'package:flutter_test/flutter_test.dart';
import 'package:kanaripay/services/price_service.dart';

void main() async {
  group('PriceService Tests', () {
    late PriceService priceService;

    setUp(() {
      priceService = PriceService();
    });

    test('Should fetch ETH price from CoinGecko API', () async {
      final price = await priceService.getTokenPrice('ETH');
      print('ETH Price: \$${price.toStringAsFixed(2)}');
      
      expect(price, greaterThan(0));
      expect(price, lessThan(100000)); // Reasonable range
    });

    test('Should fetch BTC price from CoinGecko API', () async {
      final price = await priceService.getTokenPrice('BTC');
      print('BTC Price: \$${price.toStringAsFixed(2)}');
      
      expect(price, greaterThan(0));
      expect(price, lessThan(200000)); // Reasonable range
    });

    test('Should fetch multiple prices at once', () async {
      final prices = await priceService.getMultipleTokenPrices(['ETH', 'BTC', 'MATIC']);
      print('Multiple Prices: $prices');
      
      expect(prices['ETH'], greaterThan(0));
      expect(prices['BTC'], greaterThan(0));
      expect(prices['MATIC'], greaterThan(0));
    });

    test('Should handle unknown tokens with error', () async {
      try {
        await priceService.getTokenPrice('UNKNOWN_TOKEN');
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e, isA<Exception>());
        print('Expected error for unknown token: $e');
      }
    });

    test('Should cache prices', () async {
      // First call - should fetch from API
      final price1 = await priceService.getTokenPrice('ETH');
      
      // Second call - should use cache
      final price2 = await priceService.getTokenPrice('ETH');
      
      expect(price1, equals(price2));
      
      // Check cache status
      final cacheStatus = priceService.getCacheStatus();
      print('Cache Status: $cacheStatus');
      expect(cacheStatus.containsKey('ethereum'), isTrue);
    });

    test('Should clear cache', () async {
      // Fetch a price to populate cache
      await priceService.getTokenPrice('ETH');
      
      // Verify cache has data
      var cacheStatus = priceService.getCacheStatus();
      expect(cacheStatus.isNotEmpty, isTrue);
      
      // Clear cache
      priceService.clearCache();
      
      // Verify cache is empty
      cacheStatus = priceService.getCacheStatus();
      expect(cacheStatus.isEmpty, isTrue);
    });
  });
}
