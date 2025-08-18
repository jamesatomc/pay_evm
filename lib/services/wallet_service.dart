import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:pointycastle/export.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
import 'network_service.dart';

// Custom HTTP client that adds proper headers for JSON-RPC
class JsonRpcClient extends BaseClient {
  final Client _inner = Client();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    // Add proper headers for JSON-RPC requests
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'application/json';
    
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

class WalletService {
  static const String _walletKey = 'wallet_data';
  static const String _activeWalletKey = 'active_wallet';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  final NetworkService _networkService = NetworkService();
  Web3Client? _web3client;
  NetworkModel? _currentNetwork;

  WalletService();

  Future<void> _initializeNetwork() async {
    try {
      _currentNetwork = await _networkService.getActiveNetwork();
      _web3client?.dispose(); // Dispose old client if exists
      
      // Create HTTP client with proper headers for JSON-RPC
      final httpClient = JsonRpcClient();
      _web3client = Web3Client(
        _currentNetwork!.rpcUrl, 
        httpClient,
        socketConnector: () => throw UnimplementedError('WebSocket not supported'),
      );
      
      print('Network initialized: ${_currentNetwork!.name} (${_currentNetwork!.rpcUrl})');
      
      // Test connection
      await _testConnection();
    } catch (e) {
      print('Error initializing network: $e');
    }
  }

  Future<void> _testConnection() async {
    try {
      print('Testing connection to ${_currentNetwork!.name}...');
      print('RPC URL: ${_currentNetwork!.rpcUrl}');
      
      // Try to get chain ID to test connection
      final chainId = await _web3client!.getChainId().timeout(const Duration(seconds: 10));
      print('Connection test successful - Chain ID: $chainId');
      
      // Verify chain ID matches expected
      if (chainId.toInt() != _currentNetwork!.chainId) {
        print('WARNING: Chain ID mismatch! Expected: ${_currentNetwork!.chainId}, Got: $chainId');
      }
    } catch (e) {
      print('Connection test failed: $e');
      print('Error type: ${e.runtimeType}');
      if (e.toString().contains('content-type')) {
        print('This appears to be a content-type header issue');
      }
    }
  }

  Future<void> switchNetwork(String networkId) async {
    try {
      await _networkService.setActiveNetwork(networkId);
      _currentNetwork = await _networkService.getActiveNetwork();
      _web3client?.dispose(); // Dispose old client
      
      // Create new client with proper headers
      final httpClient = JsonRpcClient();
      _web3client = Web3Client(
        _currentNetwork!.rpcUrl, 
        httpClient,
        socketConnector: () => throw UnimplementedError('WebSocket not supported'),
      );
      
      print('Switched to network: ${_currentNetwork!.name}');
    } catch (e) {
      print('Error switching network: $e');
    }
  }

  Future<NetworkModel> getCurrentNetwork() async {
    // Always refresh network from storage to get latest selection
    await _initializeNetwork();
    return _currentNetwork!;
  }

  Future<void> _ensureInitialized() async {
    if (_web3client == null || _currentNetwork == null) {
      await _initializeNetwork();
    }
  }

  // Generate new wallet with mnemonic
  Future<WalletModel> createNewWallet(String walletName, {int wordCount = 12}) async {
    print('=== Creating new wallet: $walletName with $wordCount words ===');
    
    // Generate mnemonic phrase (12 or 24 words)
    final mnemonic = wordCount == 24 
        ? bip39.generateMnemonic(strength: 256) // 256 bits = 24 words
        : bip39.generateMnemonic(strength: 128); // 128 bits = 12 words
    print('Generated new mnemonic ($wordCount words): ${mnemonic.substring(0, 20)}...');
    
    return _createWalletFromMnemonic(mnemonic, walletName);
  }

  // Helper method to create wallet from existing mnemonic
  Future<WalletModel> _createWalletFromMnemonic(String mnemonic, String walletName) async {
    // Generate seed from mnemonic using BIP39
    final seed = bip39.mnemonicToSeed(mnemonic);
    print('Generated seed length: ${seed.length}');
    print('Seed preview: ${seed.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}...');
    
    // Use BIP32-like derivation but simplified
    // Take first 32 bytes of seed as private key (this is standard for simple wallets)
    var privateKeyBytes = Uint8List.fromList(seed.take(32).toList());
    
    // If the direct seed doesn't give a valid private key, use HMAC-SHA256
    if (_isInvalidPrivateKey(privateKeyBytes)) {
      print('Direct seed invalid, using HMAC derivation...');
      
      // Use HMAC-SHA256 with seed as key and a derivation path as message
      final hmac = HMac(SHA256Digest(), 64);
      final key = Uint8List.fromList(seed);
      final message = Uint8List.fromList('m/44\'/60\'/0\'/0/0'.codeUnits); // Standard Ethereum path
      
      hmac.init(KeyParameter(key));
      hmac.update(message, 0, message.length);
      
      privateKeyBytes = Uint8List(32);
      hmac.doFinal(privateKeyBytes, 0);
      
      // If still invalid, add entropy
      var attemptCount = 0;
      while (_isInvalidPrivateKey(privateKeyBytes) && attemptCount < 10) {
        final modifiedMessage = Uint8List.fromList([
          ...message,
          attemptCount & 0xFF,
          (attemptCount >> 8) & 0xFF,
        ]);
        
        hmac.reset();
        hmac.init(KeyParameter(key));
        hmac.update(modifiedMessage, 0, modifiedMessage.length);
        hmac.doFinal(privateKeyBytes, 0);
        
        attemptCount++;
        print('HMAC attempt $attemptCount');
      }
      
      if (attemptCount >= 10) {
        throw Exception('Failed to generate valid private key from mnemonic');
      }
    }
    
    print('Final private key preview: ${privateKeyBytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}...');
    
    // Create credentials from private key
    final credentials = EthPrivateKey(privateKeyBytes);
    
    // Get address
    final address = credentials.address;
    print('Generated new address: ${address.hex}');
    print('Private key preview: ${privateKeyBytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}...');
    
    final wallet = WalletModel(
      address: address.hex,
      privateKey: privateKeyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(''),
      mnemonic: mnemonic,
      name: walletName,
      createdAt: DateTime.now(),
    );

    await _saveWallet(wallet);
    await _setActiveWallet(wallet.address);
    
    return wallet;
  }

  // Validate private key (ensure it's not zero and within secp256k1 curve order)
  bool _isInvalidPrivateKey(Uint8List privateKey) {
    // Check if all bytes are zero
    if (privateKey.every((byte) => byte == 0)) {
      return true;
    }
    
    // Check if it's too large (greater than secp256k1 curve order)
    // secp256k1 order: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    final maxBytes = [
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
      0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
      0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41
    ];
    
    for (int i = 0; i < 32; i++) {
      if (privateKey[i] > maxBytes[i]) {
        return true;
      } else if (privateKey[i] < maxBytes[i]) {
        return false;
      }
    }
    
    return false; // Equal to max is still valid
  }

  // Import wallet from mnemonic
  Future<WalletModel> importWalletFromMnemonic(String mnemonic, String walletName) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    print('Importing wallet with mnemonic: ${mnemonic.substring(0, 20)}...');
    final wordCount = mnemonic.split(' ').where((word) => word.isNotEmpty).length;
    print('Mnemonic word count: $wordCount');

    // Use the same helper method to ensure consistency
    return _createWalletFromMnemonic(mnemonic, walletName);
  }

  // Import wallet from private key
  Future<WalletModel> importWalletFromPrivateKey(String privateKey, String walletName) async {
    try {
      // Create credentials from private key
      final credentials = EthPrivateKey.fromHex(privateKey);
      
      // Get address
      final address = credentials.address;
      print('Imported private key address: ${address.hex}');
      
      final wallet = WalletModel(
        address: address.hex,
        privateKey: privateKey,
        mnemonic: '', // No mnemonic when importing from private key
        name: walletName,
        createdAt: DateTime.now(),
      );

      await _saveWallet(wallet);
      await _setActiveWallet(wallet.address);
      
      return wallet;
    } catch (e) {
      throw Exception('Invalid private key');
    }
  }

  // Save wallet securely
  Future<void> _saveWallet(WalletModel wallet) async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getString(_walletKey) ?? '[]';
    final wallets = List<Map<String, dynamic>>.from(jsonDecode(walletsJson));
    
    // Remove existing wallet with same address
    wallets.removeWhere((w) => w['address'] == wallet.address);
    
    // Add new wallet
    wallets.add(wallet.toJson());
    
    await prefs.setString(_walletKey, jsonEncode(wallets));
    
    // Save private key securely
    await _secureStorage.write(key: 'pk_${wallet.address}', value: wallet.privateKey);
    if (wallet.mnemonic.isNotEmpty) {
      await _secureStorage.write(key: 'mnemonic_${wallet.address}', value: wallet.mnemonic);
    }
  }

  // Get all wallets
  Future<List<WalletModel>> getWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getString(_walletKey) ?? '[]';
    final walletsList = List<Map<String, dynamic>>.from(jsonDecode(walletsJson));
    
    List<WalletModel> wallets = [];
    
    for (var walletData in walletsList) {
      // Get private key from secure storage
      final privateKey = await _secureStorage.read(key: 'pk_${walletData['address']}') ?? '';
      final mnemonic = await _secureStorage.read(key: 'mnemonic_${walletData['address']}') ?? '';
      
      wallets.add(WalletModel(
        address: walletData['address'],
        privateKey: privateKey,
        mnemonic: mnemonic,
        name: walletData['name'],
        createdAt: DateTime.parse(walletData['createdAt']),
      ));
    }
    
    return wallets;
  }

  // Set active wallet
  Future<void> _setActiveWallet(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeWalletKey, address);
  }

  // Get active wallet
  Future<WalletModel?> getActiveWallet() async {
    final prefs = await SharedPreferences.getInstance();
    final activeAddress = prefs.getString(_activeWalletKey);
    
    if (activeAddress == null) return null;
    
    final wallets = await getWallets();
    return wallets.firstWhere(
      (wallet) => wallet.address == activeAddress,
      orElse: () => wallets.isNotEmpty ? wallets.first : throw Exception('No wallet found'),
    );
  }

  // Switch active wallet
  Future<void> switchWallet(String address) async {
    await _setActiveWallet(address);
  }

  // Get ETH balance
  Future<double> getEthBalance(String address) async {
    try {
      await _ensureInitialized();
      print('=== Getting balance ===');
      print('Address: $address');
      print('Network: ${_currentNetwork!.name}');
      print('Chain ID: ${_currentNetwork!.chainId}');
      print('Currency: ${_currentNetwork!.currencySymbol}');
      print('RPC URL: ${_currentNetwork!.rpcUrl}');
      
      final ethAddress = EthereumAddress.fromHex(address);
      
      // Add timeout to balance request
      final balance = await _web3client!.getBalance(ethAddress)
          .timeout(const Duration(seconds: 15));
      
      final balanceInEther = balance.getValueInUnit(EtherUnit.ether);
      final balanceInWei = balance.getInWei;
      
      print('Balance in Wei: $balanceInWei');
      print('Balance in Ether: $balanceInEther ${_currentNetwork!.currencySymbol}');
      print('=== Balance request completed ===');
      
      return balanceInEther;
    } catch (e) {
      print('=== Balance request failed ===');
      print('Error: $e');
      print('Network: ${_currentNetwork?.name}');
      print('RPC: ${_currentNetwork?.rpcUrl}');
      print('Address: $address');
      print('=== End error details ===');
      return 0.0;
    }
  }

  /// Fetch dynamic gas price information based on the network
  Future<Map<String, double>> getGasInfo(String networkId) async {
    await switchNetwork(networkId);
    await _ensureInitialized();
    try {
      final current = (await _web3client!.getGasPrice()).getValueInUnit(EtherUnit.gwei);
      // Adjust logic: medium = current + 20%, high = current + 50%
      final medium = current * 1.2;
      final high = current * 1.5;
      return {
        'low': double.parse(current.toStringAsFixed(2)),
        'medium': double.parse(medium.toStringAsFixed(2)),
        'high': double.parse(high.toStringAsFixed(2)),
        'min': double.parse(current.toStringAsFixed(2)),
        'max': double.parse(high.toStringAsFixed(2)),
      };
    } catch (e) {
      debugPrint('Error fetching gas info: $e');
      // fallback default
      return {
        'low': 0.4,
        'medium': 1.1,
        'high': 2.6,
        'min': 0.4,
        'max': 2.6,
      };
    }
  }

  // Delete wallet
  Future<void> deleteWallet(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final walletsJson = prefs.getString(_walletKey) ?? '[]';
    final wallets = List<Map<String, dynamic>>.from(jsonDecode(walletsJson));
    
    // Remove wallet
    wallets.removeWhere((w) => w['address'] == address);
    await prefs.setString(_walletKey, jsonEncode(wallets));
    
    // Remove from secure storage
    await _secureStorage.delete(key: 'pk_$address');
    await _secureStorage.delete(key: 'mnemonic_$address');
    
    // If this was the active wallet, set a new one or clear
    final activeAddress = prefs.getString(_activeWalletKey);
    if (activeAddress == address) {
      if (wallets.isNotEmpty) {
        await _setActiveWallet(wallets.first['address']);
      } else {
        await prefs.remove(_activeWalletKey);
      }
    }
  }

  // Send ETH transaction
  Future<String> sendEth({
    required String fromAddress,
    required String toAddress,
    required double amount,
    double? gasPrice, // Gas price in Gwei
    String? networkId, // Optional network ID to switch before sending
  }) async {
    try {
      // Switch network if networkId is provided
      if (networkId != null) {
        await switchNetwork(networkId);
      }
      print('Starting transaction...');
      print('=== Sending transaction ===');
      print('From: $fromAddress');
      print('To: $toAddress');
      print('Amount: $amount ${_currentNetwork?.currencySymbol ?? 'ETH'}');
      print('Network: ${_currentNetwork?.name}');
      print('Chain ID: ${_currentNetwork?.chainId}');
      
      // Get private key
      final privateKey = await _secureStorage.read(key: 'pk_$fromAddress');
      if (privateKey == null) throw Exception('Private key not found');
      
      final credentials = EthPrivateKey.fromHex(privateKey);
      final to = EthereumAddress.fromHex(toAddress);
      
      // Ensure web3 client is initialized
      await _ensureInitialized();
      
      // Get current gas price if not provided
      EtherAmount? gasPriceAmount;
      if (gasPrice != null) {
        // Convert Gwei to Wei using string conversion to avoid precision issues
        final gasPriceWeiString = (gasPrice * 1000000000).toStringAsFixed(0);
        final gasPriceWei = BigInt.parse(gasPriceWeiString);
        gasPriceAmount = EtherAmount.inWei(gasPriceWei);
        print('Gas price: $gasPrice Gwei');
      } else {
        try {
          gasPriceAmount = await _web3client!.getGasPrice();
          print('Using network gas price: ${gasPriceAmount.getInWei}');
        } catch (e) {
          print('Could not fetch gas price, using default');
          gasPriceAmount = EtherAmount.inWei(BigInt.from(20000000000)); // 20 Gwei
        }
      }
      
      // Create transaction with explicit values - use string conversion for precision
      final amountString = amount.toStringAsFixed(18); // Ensure precision to 18 decimal places
      final amountInWei = BigInt.parse((double.parse(amountString) * 1e18).toStringAsFixed(0));
      print('Amount: $amount ETH = $amountInWei Wei');
      
      final transaction = Transaction(
        to: to,
        value: EtherAmount.inWei(amountInWei),
        gasPrice: gasPriceAmount,
        maxGas: 21000,
      );
      
      print('Sending transaction with gas price: ${gasPriceAmount.getInWei} Wei');
      
      final txHash = await _web3client!.sendTransaction(
        credentials,
        transaction,
        chainId: _currentNetwork?.chainId,
      );
      
      print('=== Transaction successful ===');
      print('TX Hash: $txHash');
      return txHash;
      
    } catch (e) {
      print('=== Transaction failed ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');
      print('=== End transaction error ===');
      throw Exception('Failed to send transaction: $e');
    }
  }

  void dispose() {
    _web3client?.dispose();
  }
}
