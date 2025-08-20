import 'dart:convert';
import 'package:sui/sui.dart' as sui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/network_model.dart';

class NetworkService {
  static const String _networksKey = 'custom_networks';
  static const String _activeNetworkKey = 'active_network';

  // Predefined networks
  static final List<NetworkModel> _predefinedNetworks = [
    // Sui networks
    NetworkModel(
      id: 'sui-devnet',
      name: 'Sui Devnet',
      rpcUrl: sui.SuiUrls.devnet,
      chainId: 0,
      currencySymbol: 'SUI',
      blockExplorerUrl: null,
      isTestnet: true,
      iconPath: 'assets/icons/sui.png',
    ),
    NetworkModel(
      id: 'sui-testnet',
      name: 'Sui Testnet',
      rpcUrl: sui.SuiUrls.testnet,
      chainId: 0,
      currencySymbol: 'SUI',
      blockExplorerUrl: null,
      isTestnet: true,
      iconPath: 'assets/icons/sui.png',
    ),
    NetworkModel(
      id: 'sui-mainnet',
      name: 'Sui Mainnet',
      rpcUrl: sui.SuiUrls.mainnet,
      chainId: 0,
      currencySymbol: 'SUI',
      blockExplorerUrl: null,
      isTestnet: false,
      iconPath: 'assets/icons/sui.png',
    ),
    // Ethereum Mainnet
    const NetworkModel(
      id: 'ethereum',
      name: 'Ethereum',
      rpcUrl: 'https://eth.llamarpc.com',
      chainId: 1,
      currencySymbol: 'ETH',
      blockExplorerUrl: 'https://etherscan.io',
      isTestnet: false,
      iconPath: 'assets/icons/ethereum.png',
    ),
    
    // Ethereum Sepolia Testnet
    const NetworkModel(
      id: 'sepolia',
      name: 'Sepolia Testnet',
      rpcUrl: 'https://rpc.sepolia.org',
      chainId: 11155111,
      currencySymbol: 'ETH',
      blockExplorerUrl: 'https://sepolia.etherscan.io',
      isTestnet: true,
      iconPath: 'assets/icons/ethereum.png',
    ),

    // BNB Smart Chain
    const NetworkModel(
      id: 'bsc',
      name: 'BNB Smart Chain',
      rpcUrl: 'https://bsc-dataseed1.binance.org',
      chainId: 56,
      currencySymbol: 'BNB',
      blockExplorerUrl: 'https://bscscan.com',
      isTestnet: false,
      iconPath: 'assets/icons/bnb.png',
    ),

    // BNB Smart Chain Testnet
    const NetworkModel(
      id: 'bsc-testnet',
      name: 'BNB Smart Chain Testnet',
      rpcUrl: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      currencySymbol: 'tBNB',
      blockExplorerUrl: 'https://testnet.bscscan.com',
      isTestnet: true,
      iconPath: 'assets/icons/bnb.png',
    ),

    // Alpen Testnet
    const NetworkModel(
      id: 'alpen-testnet',
      name: 'Alpen Testnet',
      rpcUrl: 'https://rpc.testnet.alpenlabs.io',
      chainId: 2892,
      currencySymbol: 'sBTC',
      blockExplorerUrl: 'https://explorer.testnet.alpenlabs.io',
      isTestnet: true,
      iconPath: 'assets/icons/alpen.png',
      iconUrl: 'https://avatars.githubusercontent.com/u/113091135',
    ),

    // Monad Testnet
    const NetworkModel(
      id: 'monad-testnet',
      name: 'Monad Testnet',
      rpcUrl: 'https://rpc.ankr.com/monad_testnet',
      chainId: 10143,
      currencySymbol: 'MON',
      blockExplorerUrl: 'https://testnet.monadexplorer.com/',
      isTestnet: true,
      iconPath: 'assets/icons/monad.png',
      iconUrl: 'https://avatars.githubusercontent.com/u/191391794?s=200&v=4'
    ),

  ];

  // Get all available networks (predefined + custom)
  Future<List<NetworkModel>> getAllNetworks() async {
    final customNetworks = await getCustomNetworks();
    return [..._predefinedNetworks, ...customNetworks];
  }

  // Get predefined networks only
  List<NetworkModel> getPredefinedNetworks() {
    return _predefinedNetworks;
  }

  // Get custom networks only
  Future<List<NetworkModel>> getCustomNetworks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final networksJson = prefs.getString(_networksKey);
      
      if (networksJson == null) return [];
      
      final List<dynamic> networksList = jsonDecode(networksJson);
      return networksList
          .map((json) => NetworkModel.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading custom networks: $e');
      return [];
    }
  }

  // Add custom network
  Future<bool> addCustomNetwork(NetworkModel network) async {
    try {
      final customNetworks = await getCustomNetworks();
      
      // Check if network already exists
      if (customNetworks.any((n) => n.id == network.id || n.chainId == network.chainId)) {
        return false; // Network already exists
      }
      
      customNetworks.add(network.copyWith(isCustom: true));
      
      final prefs = await SharedPreferences.getInstance();
      final networksJson = jsonEncode(customNetworks.map((n) => n.toJson()).toList());
      await prefs.setString(_networksKey, networksJson);
      
      return true;
    } catch (e) {
      print('Error adding custom network: $e');
      return false;
    }
  }

  // Update custom network
  Future<bool> updateCustomNetwork(NetworkModel network) async {
    try {
      final customNetworks = await getCustomNetworks();
      final index = customNetworks.indexWhere((n) => n.id == network.id);
      
      if (index == -1) return false;
      
      customNetworks[index] = network.copyWith(isCustom: true);
      
      final prefs = await SharedPreferences.getInstance();
      final networksJson = jsonEncode(customNetworks.map((n) => n.toJson()).toList());
      await prefs.setString(_networksKey, networksJson);
      
      return true;
    } catch (e) {
      print('Error updating custom network: $e');
      return false;
    }
  }

  // Remove custom network
  Future<bool> removeCustomNetwork(String networkId) async {
    try {
      final customNetworks = await getCustomNetworks();
      customNetworks.removeWhere((n) => n.id == networkId);
      
      final prefs = await SharedPreferences.getInstance();
      final networksJson = jsonEncode(customNetworks.map((n) => n.toJson()).toList());
      await prefs.setString(_networksKey, networksJson);
      
      return true;
    } catch (e) {
      print('Error removing custom network: $e');
      return false;
    }
  }

  // Get active network
  Future<NetworkModel> getActiveNetwork() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeNetworkId = prefs.getString(_activeNetworkKey);
      
      if (activeNetworkId == null) {
        // Default to Ethereum mainnet
        return _predefinedNetworks.first;
      }
      
      final allNetworks = await getAllNetworks();
      final network = allNetworks.firstWhere(
        (n) => n.id == activeNetworkId,
        orElse: () => _predefinedNetworks.first,
      );
      
      return network;
    } catch (e) {
      print('Error getting active network: $e');
      return _predefinedNetworks.first;
    }
  }

  // Set active network
  Future<void> setActiveNetwork(String networkId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeNetworkKey, networkId);
    } catch (e) {
      print('Error setting active network: $e');
    }
  }

  // Test network connection
  Future<bool> testNetworkConnection(String rpcUrl) async {
    try {
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_chainId',
          'params': [],
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Network test failed: $e');
      return false;
    }
  }

  // Get network by chain ID
  Future<NetworkModel?> getNetworkByChainId(int chainId) async {
    final allNetworks = await getAllNetworks();
    try {
      return allNetworks.firstWhere((n) => n.chainId == chainId);
    } catch (e) {
      return null;
    }
  }

  // Get network by ID
  Future<NetworkModel?> getNetworkById(String id) async {
    final allNetworks = await getAllNetworks();
    try {
      return allNetworks.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }
}
