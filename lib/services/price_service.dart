import 'dart:convert';
import 'package:http/http.dart' as http;

class PriceService {
  static const String _baseUrl = 'https://api.coingecko.com/api/v3';
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  // Cache for prices
  static final Map<String, Map<String, dynamic>> _priceCache = {};
  
  // Map cryptocurrency symbols to CoinGecko IDs
  Map<String, String> _getSymbolToIdMap() {
    return {
      'ETH': 'ethereum',
      'BTC': 'bitcoin', 
      'SBTC': 'bitcoin', // sBTC (Signet Bitcoin) uses Bitcoin price (uppercase key)
      'BNB': 'binancecoin',
      'MATIC': 'matic-network',
      'AVAX': 'avalanche-2',
      'FTM': 'fantom',
      'USDC': 'usd-coin',
      'USDT': 'tether',
      'DAI': 'dai',
      'LINK': 'chainlink',
      'UNI': 'uniswap',
    };
  }

  // Get price for a single token
  Future<double> getTokenPrice(String symbol) async {
    try {
      // Hardcode the mapping for now to test
      final Map<String, String> symbolToId = {
        'ETH': 'ethereum',
        'BTC': 'bitcoin', 
        'SBTC': 'bitcoin', // sBTC uses Bitcoin price (uppercase key)
        'BNB': 'binancecoin',
        'MATIC': 'matic-network',
        'AVAX': 'avalanche-2',
        'FTM': 'fantom',
        'USDC': 'usd-coin',
        'USDT': 'tether',
        'DAI': 'dai',
        'LINK': 'chainlink',
        'UNI': 'uniswap',
      };
      
      final upperSymbol = symbol.toUpperCase();
      print('DEBUG: Looking for symbol: $symbol (upper: $upperSymbol)');
      print('DEBUG: Available symbols: ${symbolToId.keys.toList()}');
      print('DEBUG: Map contains SBTC: ${symbolToId.containsKey('SBTC')}');
      
      final coinId = symbolToId[upperSymbol];
      print('DEBUG: Found coinId for $upperSymbol: $coinId');
      
      if (coinId == null) {
        print('No CoinGecko ID found for symbol: $symbol');
        throw Exception('Unsupported token: $symbol');
      }

      // Check cache first
      if (_isCacheValid(coinId)) {
        final cachedPrice = _priceCache[coinId]!['price'] as double;
        print('Using cached price for $symbol: \$${cachedPrice.toStringAsFixed(2)}');
        return cachedPrice;
      }

      // Fetch from API
      final response = await http.get(
        Uri.parse('$_baseUrl/simple/price?ids=$coinId&vs_currencies=usd'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final price = (data[coinId]['usd'] as num).toDouble();
        
        // Cache the result
        _priceCache[coinId] = {
          'price': price,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        print('Fetched price for $symbol: \$${price.toStringAsFixed(2)}');
        return price;
      } else {
        print('Failed to fetch price for $symbol: ${response.statusCode}');
        throw Exception('Failed to fetch price from API');
      }
    } catch (e) {
      print('Error fetching price for $symbol: $e');
      throw Exception('Unable to fetch price for $symbol');
    }
  }

  // Get prices for multiple tokens
  Future<Map<String, double>> getMultipleTokenPrices(List<String> symbols) async {
    try {
      final symbolToId = _getSymbolToIdMap();
      final coinIds = <String>[];
      final symbolToIdMap = <String, String>{};
      
      // Map symbols to coin IDs
      for (final symbol in symbols) {
        final coinId = symbolToId[symbol.toUpperCase()];
        if (coinId != null) {
          coinIds.add(coinId);
          symbolToIdMap[coinId] = symbol.toUpperCase();
        }
      }
      
      if (coinIds.isEmpty) {
        throw Exception('No supported tokens found');
      }

      // Check cache for all coins
      final uncachedIds = <String>[];
      final Map<String, double> result = {};
      
      for (final coinId in coinIds) {
        if (_isCacheValid(coinId)) {
          final symbol = symbolToIdMap[coinId]!;
          result[symbol] = _priceCache[coinId]!['price'] as double;
        } else {
          uncachedIds.add(coinId);
        }
      }

      // Fetch uncached prices
      if (uncachedIds.isNotEmpty) {
        final idsString = uncachedIds.join(',');
        final response = await http.get(
          Uri.parse('$_baseUrl/simple/price?ids=$idsString&vs_currencies=usd'),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          for (final coinId in uncachedIds) {
            if (data[coinId] != null) {
              final price = (data[coinId]['usd'] as num).toDouble();
              final symbol = symbolToIdMap[coinId]!;
              
              // Cache the result
              _priceCache[coinId] = {
                'price': price,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };
              
              result[symbol] = price;
            }
          }
        }
      }

      // Fill in missing data as errors
      for (final symbol in symbols) {
        if (!result.containsKey(symbol.toUpperCase())) {
          throw Exception('Unable to fetch price for $symbol');
        }
      }
      
      print('Fetched prices: ${result.entries.map((e) => '${e.key}: \$${e.value.toStringAsFixed(2)}').join(', ')}');
      return result;
    } catch (e) {
      print('Error fetching multiple prices: $e');
      rethrow;
    }
  }

  // Check if cached price is still valid
  bool _isCacheValid(String coinId) {
    if (!_priceCache.containsKey(coinId)) return false;
    
    final timestamp = _priceCache[coinId]!['timestamp'] as int;
    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    
    return cacheAge < _cacheTimeout.inMilliseconds;
  }

  // Clear cache (useful for testing or manual refresh)
  void clearCache() {
    _priceCache.clear();
    print('Price cache cleared');
  }

  // Get cache status
  Map<String, dynamic> getCacheStatus() {
    final status = <String, dynamic>{};
    for (final entry in _priceCache.entries) {
      final coinId = entry.key;
      final data = entry.value;
      final timestamp = data['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      
      status[coinId] = {
        'price': data['price'],
        'age_minutes': (age / 60000).round(),
        'is_valid': _isCacheValid(coinId),
      };
    }
    return status;
  }
}
