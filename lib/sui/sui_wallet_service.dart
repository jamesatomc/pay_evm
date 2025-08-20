import 'dart:convert';
import 'package:sui/sui.dart' as sui;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/network_model.dart';
import '../services/network_service.dart';
import 'sui_wallet.dart';

/// Small service that encapsulates Sui client initialization and common Sui RPC
/// helpers. This keeps Sui-specific logic out of the generic `WalletService`.
class SuiWalletService {
  sui.SuiClient? _suiClient;
  NetworkModel? _currentNetwork;

  SuiWalletService();

  sui.SuiClient? get suiClient => _suiClient;
  bool get hasSuiClient => _suiClient != null;

  /// Initialize the Sui client based on the provided [network]. If the network
  /// is not a Sui network the client will be set to null.
  Future<void> initializeForNetwork(NetworkModel network) async {
    _currentNetwork = network;
    try {
      final id = network.id.toLowerCase();
      if (id.contains('sui')) {
        if (id.contains('dev') || id.contains('devnet')) {
          _suiClient = sui.SuiClient(sui.SuiUrls.devnet);
        } else if (id.contains('test') || id.contains('testnet')) {
          _suiClient = sui.SuiClient(sui.SuiUrls.testnet);
        } else {
          _suiClient = sui.SuiClient(sui.SuiUrls.mainnet);
        }
      } else {
        _suiClient = null;
      }
    } catch (e) {
      print('Error initializing Sui client: $e');
      _suiClient = null;
    }
  }

  /// Import a Sui wallet from mnemonic using the helpers in `sui_wallet.dart`.
  Future<SuiWallet> importFromMnemonic(String mnemonic,
      {SuiSignatureScheme scheme = SuiSignatureScheme.ed25519}) async {
    return await importSuiFromMnemonic(mnemonic, scheme: scheme);
  }

  /// Import a Sui wallet from a private key string.
  Future<SuiWallet> importFromPrivateKey(String privateKey,
      {SuiSignatureScheme scheme = SuiSignatureScheme.ed25519}) async {
    return await importSuiFromPrivateKey(privateKey, scheme: scheme);
  }

  /// Generate a new Sui wallet (mnemonic + keys).
  Future<SuiWallet> generateWallet({SuiSignatureScheme scheme = SuiSignatureScheme.ed25519}) async {
    return await generateSuiWallet(scheme: scheme);
  }

  Future<List<dynamic>> getSuiCoins(String address, {String? coinType}) async {
    if (_suiClient == null) return [];
    try {
      final dynamic resp = await _suiClient!.getCoins(address, coinType: coinType);
      if (resp is List) return List<dynamic>.from(resp);
      try {
        if (resp.data != null) return List<dynamic>.from(resp.data);
        if (resp.result != null) return List<dynamic>.from(resp.result);
      } catch (_) {}
      return [];
    } catch (e) {
      print('Error getSuiCoins: $e');
      return [];
    }
  }

  Future<List<dynamic>> getAllSuiCoins(String address) async {
    if (_suiClient == null) return [];
    try {
      final dynamic resp = await _suiClient!.getAllCoins(address);
      if (resp is List) return List<dynamic>.from(resp);
      try {
        if (resp.data != null) return List<dynamic>.from(resp.data);
        if (resp.result != null) return List<dynamic>.from(resp.result);
      } catch (_) {}
      return [];
    } catch (e) {
      print('Error getAllSuiCoins: $e');
      return [];
    }
  }

  Future<int> getSuiCoinCount(String address) async {
    try {
      if (_suiClient != null) {
        final all = await getAllSuiCoins(address);
        return all.length;
      }

      // fallback to RPC
      final uri = Uri.parse(_currentNetwork!.rpcUrl);
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'sui_getAllCoins',
        'params': [address]
      });
      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final result = decoded['result'];
        if (result is List) return result.length;
      }
      return 0;
    } catch (e) {
      print('Error getSuiCoinCount: $e');
      return 0;
    }
  }

  Future<double> getSuiBalance(String address) async {
    try {
      if (_suiClient != null) {
        try {
          final balRaw = await _suiClient!.getBalance(address);
          try {
            final dynamic d = balRaw;
            dynamic tb;
            try {
              tb = d.totalBalance;
            } catch (_) {
              tb = null;
            }
            if (tb == null) {
              try {
                tb = (d as dynamic)['totalBalance'];
              } catch (_) {
                tb = null;
              }
            }
            if (tb != null) {
              final balNum = tb is num ? tb.toDouble() : double.tryParse(tb.toString()) ?? 0.0;
              return balNum / 1000000000.0;
            }

            final rawString = d.toString();
            final match = RegExp(r"(\d+)").firstMatch(rawString);
            if (match != null) {
              final digits = match.group(0)!;
              final parsedBig = BigInt.tryParse(digits);
              if (parsedBig != null) return parsedBig.toDouble() / 1000000000.0;
              final parsedDouble = double.tryParse(digits);
              if (parsedDouble != null) return parsedDouble / 1000000000.0;
            }
          } catch (e) {
            print('Error parsing SuiClient.getBalance result: $e');
          }
          return 0.0;
        } catch (e) {
          print('Error reading balance from SuiClient: $e');
        }
      }

      // Fallback RPC
      final uri = Uri.parse(_currentNetwork!.rpcUrl);
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'sui_getBalance',
        'params': [address]
      });

      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final result = decoded['result'];
        if (result != null) {
          if (result is Map && result['totalBalance'] != null) {
            final tb = result['totalBalance'];
            final bal = double.tryParse(tb.toString()) ?? 0.0;
            return bal / 1000000000.0;
          }
          if (result is Map && result['balance'] != null) {
            final b = result['balance'];
            final bal = double.tryParse(b.toString()) ?? 0.0;
            return bal / 1000000000.0;
          }
          if (result is Map && result['data'] is List) {
            double sum = 0.0;
            for (final item in result['data']) {
              try {
                final bal = double.tryParse(item['balance'].toString()) ?? 0.0;
                sum += bal;
              } catch (_) {}
            }
            return sum / 1000000000.0;
          }
          final raw = result is num ? result : result.toString();
          final bal = double.tryParse(raw.toString()) ?? 0.0;
          return bal / 1000000000.0;
        }
      }

      return 0.0;
    } catch (e) {
      print('Error fetching Sui balance: $e');
      return 0.0;
    }
  }

  /// Return the currently active network, initializing the Sui client if needed.
  Future<NetworkModel> getCurrentNetwork() async {
    final ns = NetworkService();
    final network = await ns.getActiveNetwork();
    await initializeForNetwork(network);
    return network;
  }

  /// Dispose internal resources held by the Sui service.
  void dispose() {
    // The underlying Sui client doesn't expose a dispose API, but clear
    // references to allow GC and avoid accidental reuse.
    _suiClient = null;
    _currentNetwork = null;
  }

  /// Send SUI transaction - placeholder implementation.
  ///
  /// Implementing a fully working Sui transfer requires signing and
  /// submitting a transaction with the user's private key. For now this
  /// method is a stub that surfaces as unimplemented at runtime so calling
  /// code can handle the error rather than failing static analysis.
  Future<String> sendSui({
    required String fromAddress,
    required String toAddress,
    required double amount,
    String? networkId,
  }) async {
    // Ensure client initialized for the active network (or provided network)
    if (networkId != null) {
      final ns = NetworkService();
      final n = await ns.getNetworkById(networkId) ?? await ns.getActiveNetwork();
      await initializeForNetwork(n);
    } else if (_currentNetwork == null) {
      await getCurrentNetwork();
    }

    // Read private key from secure storage (stored by WalletService as 'pk_<address>')
    final storage = const FlutterSecureStorage();
    final privateKey = await storage.read(key: 'pk_$fromAddress');
    if (privateKey == null || privateKey.isEmpty) {
      throw Exception('Private key for $fromAddress not found in secure storage');
    }

    // Ensure Sui client available
    if (_suiClient == null) {
      throw Exception('Sui client not initialized for network ${_currentNetwork?.id ?? networkId ?? 'unknown'}');
    }

    // Convert amount to Sui base units (package and code above use 1 SUI = 1e9)
    final BigInt amountRaw;
    try {
      amountRaw = BigInt.from((amount * 1000000000).round());
    } catch (e) {
      throw Exception('Invalid amount');
    }

    try {
      // Create account from private key using default Ed25519 scheme
      final account = sui.SuiAccount.fromPrivateKey(privateKey, sui.SignatureScheme.Ed25519);

      // Build a transaction block to transfer SUI using the SDK Transaction builder
      final tx = sui.Transaction();

      // Split coins from the gas object to create a coin for the requested amount
      // Note: Transaction API expects amounts in base units (same units used elsewhere: 1 SUI = 1e9)
      final coin = tx.splitCoins(tx.gas, [amountRaw]);

      // Transfer the split coin to the recipient
      tx.transferObjects([coin], toAddress);

      // Sign and execute the transaction block
      final result = await (_suiClient as dynamic).signAndExecuteTransactionBlock(account, tx);

      // Parse and return digest/hash
      if (result == null) throw Exception('Empty response from Sui client');
      try {
        // result may be a typed object with a `digest` field or a Map
        if (result is Map && result['digest'] != null) return result['digest'].toString();
        // Some typed responses expose `.digest`
        final dyn = result as dynamic;
        if (dyn.digest != null) return dyn.digest.toString();
      } catch (_) {}

      // Fallback to string representation
      final asString = result.toString();
      if (asString.isNotEmpty) return asString;

      throw Exception('Unknown response when sending SUI: $result');
    } catch (e) {
      throw Exception('Failed to send SUI: $e');
    }
  }

  
}
