import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:pointycastle/export.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
import 'network_service.dart';

class WalletService {
  static const String _walletKey = 'wallet_data';
  static const String _activeWalletKey = 'active_wallet';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  final NetworkService _networkService = NetworkService();
  Web3Client? _web3client;
  NetworkModel? _currentNetwork;

  WalletService() {
    _initializeNetwork();
  }

  Future<void> _initializeNetwork() async {
    _currentNetwork = await _networkService.getActiveNetwork();
    _web3client = Web3Client(_currentNetwork!.rpcUrl, Client());
  }

  Future<void> switchNetwork(String networkId) async {
    await _networkService.setActiveNetwork(networkId);
    _currentNetwork = await _networkService.getActiveNetwork();
    _web3client = Web3Client(_currentNetwork!.rpcUrl, Client());
  }

  Future<NetworkModel> getCurrentNetwork() async {
    if (_currentNetwork == null) {
      await _initializeNetwork();
    }
    return _currentNetwork!;
  }

  // Generate new wallet with mnemonic
  Future<WalletModel> createNewWallet(String walletName) async {
    // Generate mnemonic phrase
    final mnemonic = bip39.generateMnemonic();
    
    // Generate seed from mnemonic
    final seed = bip39.mnemonicToSeed(mnemonic);
    
    // Generate private key from seed (simplified approach)
    final digest = SHA256Digest();
    final privateKeyBytes = Uint8List(32);
    final seedBytes = Uint8List.fromList(seed);
    digest.process(seedBytes);
    digest.doFinal(privateKeyBytes, 0);
    
    // Create credentials from private key
    final credentials = EthPrivateKey(privateKeyBytes);
    
    // Get address
    final address = await credentials.extractAddress();
    
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

  // Import wallet from mnemonic
  Future<WalletModel> importWalletFromMnemonic(String mnemonic, String walletName) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic phrase');
    }

    // Generate seed from mnemonic
    final seed = bip39.mnemonicToSeed(mnemonic);
    
    // Generate private key from seed (simplified approach)
    final digest = SHA256Digest();
    final privateKeyBytes = Uint8List(32);
    final seedBytes = Uint8List.fromList(seed);
    digest.process(seedBytes);
    digest.doFinal(privateKeyBytes, 0);
    
    // Create credentials from private key
    final credentials = EthPrivateKey(privateKeyBytes);
    
    // Get address
    final address = await credentials.extractAddress();
    
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

  // Import wallet from private key
  Future<WalletModel> importWalletFromPrivateKey(String privateKey, String walletName) async {
    try {
      // Create credentials from private key
      final credentials = EthPrivateKey.fromHex(privateKey);
      
      // Get address
      final address = await credentials.extractAddress();
      
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
      if (_web3client == null) await _initializeNetwork();
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await _web3client!.getBalance(ethAddress);
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      print('Error getting ETH balance: $e');
      return 0.0;
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
    double? gasPrice,
  }) async {
    try {
      final privateKey = await _secureStorage.read(key: 'pk_$fromAddress');
      if (privateKey == null) throw Exception('Private key not found');
      
      final credentials = EthPrivateKey.fromHex(privateKey);
      final to = EthereumAddress.fromHex(toAddress);
      
      final etherAmount = EtherAmount.fromUnitAndValue(EtherUnit.ether, amount);
      
      final transaction = Transaction(
        to: to,
        gasPrice: gasPrice != null ? EtherAmount.inWei(BigInt.from(gasPrice)) : null,
        maxGas: 21000,
        value: etherAmount,
      );
      
      if (_web3client == null) await _initializeNetwork();
      final txHash = await _web3client!.sendTransaction(
        credentials,
        transaction,
        chainId: _currentNetwork!.chainId,
      );
      
      return txHash;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  void dispose() {
    _web3client?.dispose();
  }
}
