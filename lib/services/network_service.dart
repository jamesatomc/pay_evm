import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/network_model.dart';

class NetworkService {
  static const String _networksKey = 'custom_networks';
  static const String _activeNetworkKey = 'active_network';

  // Predefined networks
  static final List<NetworkModel> _predefinedNetworks = [
    // Ethereum Mainnet
    const NetworkModel(
      id: 'ethereum',
      name: 'Ethereum',
      rpcUrl: 'https://mainnet.infura.io/v3/YOUR_PROJECT_ID',
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
      rpcUrl: 'https://sepolia.infura.io/v3/YOUR_PROJECT_ID',
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

    // Polygon
    const NetworkModel(
      id: 'polygon',
      name: 'Polygon',
      rpcUrl: 'https://polygon-rpc.com',
      chainId: 137,
      currencySymbol: 'MATIC',
      blockExplorerUrl: 'https://polygonscan.com',
      isTestnet: false,
      iconPath: 'assets/icons/polygon.png',
    ),

    // Mumbai Testnet
    const NetworkModel(
      id: 'mumbai',
      name: 'Mumbai Testnet',
      rpcUrl: 'https://rpc-mumbai.maticvigil.com',
      chainId: 80001,
      currencySymbol: 'MATIC',
      blockExplorerUrl: 'https://mumbai.polygonscan.com',
      isTestnet: true,
      iconPath: 'assets/icons/polygon.png',
    ),

    // Avalanche
    const NetworkModel(
      id: 'avalanche',
      name: 'Avalanche C-Chain',
      rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
      chainId: 43114,
      currencySymbol: 'AVAX',
      blockExplorerUrl: 'https://snowtrace.io',
      isTestnet: false,
      iconPath: 'assets/icons/avalanche.png',
    ),

    // Avalanche Fuji Testnet
    const NetworkModel(
      id: 'fuji',
      name: 'Avalanche Fuji Testnet',
      rpcUrl: 'https://api.avax-test.network/ext/bc/C/rpc',
      chainId: 43113,
      currencySymbol: 'AVAX',
      blockExplorerUrl: 'https://testnet.snowtrace.io',
      isTestnet: true,
      iconPath: 'assets/icons/avalanche.png',
    ),

    // Fantom
    const NetworkModel(
      id: 'fantom',
      name: 'Fantom Opera',
      rpcUrl: 'https://rpc.ftm.tools',
      chainId: 250,
      currencySymbol: 'FTM',
      blockExplorerUrl: 'https://ftmscan.com',
      isTestnet: false,
      iconPath: 'assets/icons/fantom.png',
    ),

    // Fantom Testnet
    const NetworkModel(
      id: 'fantom-testnet',
      name: 'Fantom Testnet',
      rpcUrl: 'https://rpc.testnet.fantom.network',
      chainId: 4002,
      currencySymbol: 'FTM',
      blockExplorerUrl: 'https://testnet.ftmscan.com',
      isTestnet: true,
      iconPath: 'assets/icons/fantom.png',
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
