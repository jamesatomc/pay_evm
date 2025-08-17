import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/token_model.dart';
import '../models/wallet_model.dart';
import 'network_service.dart';

class TokenService {
  static const String _tokensKey = 'custom_tokens';
  static const String _tokenBalancesKey = 'token_balances';
  
  final NetworkService _networkService = NetworkService();

  // Get all custom tokens for a specific network
  Future<List<CustomTokenModel>> getCustomTokens(String networkId) async {
    final prefs = await SharedPreferences.getInstance();
    final tokensJson = prefs.getString(_tokensKey);
    
    if (tokensJson == null) return [];
    
    final Map<String, dynamic> allTokens = json.decode(tokensJson);
    final networkTokens = allTokens[networkId] as List<dynamic>?;
    
    if (networkTokens == null) return [];
    
    return networkTokens
        .map((tokenJson) => CustomTokenModel.fromJson(tokenJson))
        .toList();
  }

  // Get all tokens (native + custom) for a network
  Future<List<CustomTokenModel>> getAllTokens(String networkId) async {
    final network = await _networkService.getNetworkById(networkId);
    if (network == null) return [];

    final tokens = <CustomTokenModel>[];
    
    // Add native token
    final nativeToken = CustomTokenModel.native(
      name: network.name,
      symbol: network.currencySymbol,
      networkId: networkId,
      iconUrl: network.iconUrl,
    );
    tokens.add(nativeToken);
    
    // Add custom tokens
    final customTokens = await getCustomTokens(networkId);
    tokens.addAll(customTokens);
    
    return tokens;
  }

  // Add a custom token
  Future<bool> addCustomToken(CustomTokenModel token) async {
    try {
      print('TokenService: Adding custom token ${token.symbol} for network ${token.networkId}');
      final prefs = await SharedPreferences.getInstance();
      final tokensJson = prefs.getString(_tokensKey);
      
      Map<String, dynamic> allTokens = {};
      if (tokensJson != null) {
        allTokens = json.decode(tokensJson);
        print('TokenService: Existing tokens loaded: ${allTokens.keys}');
      } else {
        print('TokenService: No existing tokens found');
      }
      
      // Get tokens for this network only
      List<dynamic> networkTokens = allTokens[token.networkId] ?? [];
      print('TokenService: Current tokens for network ${token.networkId}: ${networkTokens.length}');
      
      // Check if token already exists in THIS SPECIFIC NETWORK only
      final exists = networkTokens.any((t) {
        final existingToken = CustomTokenModel.fromJson(t);
        final addressMatch = existingToken.contractAddress.toLowerCase() == token.contractAddress.toLowerCase();
        final networkMatch = existingToken.networkId == token.networkId;
        return addressMatch && networkMatch;
      });
      
      if (exists) {
        print('TokenService: Token already exists in network ${token.networkId}');
        return false;
      }
      
      print('TokenService: Token not found in network ${token.networkId}, proceeding to add');
      
      // Add the new token to this specific network
      networkTokens.add(token.toJson());
      allTokens[token.networkId] = networkTokens;
      
      // Save back to preferences
      await prefs.setString(_tokensKey, json.encode(allTokens));
      print('TokenService: Token ${token.symbol} added successfully');
      return true;
    } catch (e) {
      print('Error adding custom token: $e');
      return false;
    }
  }

  // Remove a custom token
  Future<bool> removeCustomToken(String contractAddress, String networkId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokensJson = prefs.getString(_tokensKey);
      
      if (tokensJson == null) return false;
      
      Map<String, dynamic> allTokens = json.decode(tokensJson);
      List<dynamic> networkTokens = allTokens[networkId] ?? [];
      
      // Remove the token
      networkTokens.removeWhere((t) => 
          CustomTokenModel.fromJson(t).contractAddress.toLowerCase() == 
          contractAddress.toLowerCase());
      
      allTokens[networkId] = networkTokens;
      
      // Save back to preferences
      await prefs.setString(_tokensKey, json.encode(allTokens));
      return true;
    } catch (e) {
      print('Error removing custom token: $e');
      return false;
    }
  }

  // Update token enabled status
  Future<bool> updateTokenStatus(String contractAddress, String networkId, bool isEnabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokensJson = prefs.getString(_tokensKey);
      
      if (tokensJson == null) return false;
      
      Map<String, dynamic> allTokens = json.decode(tokensJson);
      List<dynamic> networkTokens = allTokens[networkId] ?? [];
      
      // Find and update the token
      for (int i = 0; i < networkTokens.length; i++) {
        final tokenModel = CustomTokenModel.fromJson(networkTokens[i]);
        if (tokenModel.contractAddress.toLowerCase() == contractAddress.toLowerCase()) {
          networkTokens[i] = tokenModel.copyWith(isEnabled: isEnabled).toJson();
          break;
        }
      }
      
      allTokens[networkId] = networkTokens;
      
      // Save back to preferences
      await prefs.setString(_tokensKey, json.encode(allTokens));
      return true;
    } catch (e) {
      print('Error updating token status: $e');
      return false;
    }
  }

  // Fetch token information from contract
  Future<CustomTokenModel?> fetchTokenInfo(String contractAddress, String networkId) async {
    try {
      final network = await _networkService.getNetworkById(networkId);
      if (network == null) return null;

      // This is a simplified version - in a real app you'd call the contract
      // to get token name, symbol, and decimals using web3dart
      
      // For now, we'll return a placeholder that requires manual input
      return CustomTokenModel(
        contractAddress: contractAddress,
        name: '', // Will be filled by user
        symbol: '', // Will be filled by user
        decimals: 18, // Default, can be changed by user
        networkId: networkId,
      );
    } catch (e) {
      print('Error fetching token info: $e');
      return null;
    }
  }

  // Get token balance for a wallet
  Future<double> getTokenBalance(String contractAddress, String walletAddress, String networkId) async {
    try {
      // This would normally call the token contract's balanceOf method
      // For now, return 0.0 as placeholder
      return 0.0;
    } catch (e) {
      print('Error getting token balance: $e');
      return 0.0;
    }
  }

  // Get token balances for all tokens in a wallet
  Future<List<CustomTokenModel>> getTokenBalances(WalletModel wallet, String networkId) async {
    final tokens = await getAllTokens(networkId);
    final tokensWithBalance = <CustomTokenModel>[];
    
    for (final token in tokens) {
      double balance;
      if (token.isNative) {
        // For native tokens, we might already have the balance
        balance = token.balance;
      } else {
        balance = await getTokenBalance(token.contractAddress, wallet.address, networkId);
      }
      
      tokensWithBalance.add(token.copyWith(balance: balance));
    }
    
    return tokensWithBalance;
  }

  // Search for popular tokens (this could be enhanced with a token list API)
  Future<List<CustomTokenModel>> searchPopularTokens(String networkId, String query) async {
    // This would normally fetch from a token list API like Uniswap's token list
    // For now, return some popular tokens based on network
    
    final popularTokens = <CustomTokenModel>[];
    
    if (networkId == 'ethereum' || networkId == 'sepolia') {
      popularTokens.addAll([
        CustomTokenModel(
          contractAddress: '0xA0b86a33E6441b7c946D5b7Bd3E6DE1b8e0C7a9a',
          name: 'USD Coin',
          symbol: 'USDC',
          decimals: 6,
          networkId: networkId,
          iconUrl: 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png',
        ),
        CustomTokenModel(
          contractAddress: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
          name: 'Tether USD',
          symbol: 'USDT',
          decimals: 6,
          networkId: networkId,
          iconUrl: 'https://cryptologos.cc/logos/tether-usdt-logo.png',
        ),
      ]);
    } else if (networkId == 'bsc' || networkId == 'bsc-testnet') {
      popularTokens.addAll([
        CustomTokenModel(
          contractAddress: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
          name: 'USD Coin',
          symbol: 'USDC',
          decimals: 18,
          networkId: networkId,
          iconUrl: 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png',
        ),
        CustomTokenModel(
          contractAddress: '0x55d398326f99059fF775485246999027B3197955',
          name: 'Tether USD',
          symbol: 'USDT',
          decimals: 18,
          networkId: networkId,
          iconUrl: 'https://cryptologos.cc/logos/tether-usdt-logo.png',
        ),
      ]);
    }
    
    // Filter by query if provided
    if (query.isNotEmpty) {
      return popularTokens.where((token) =>
          token.name.toLowerCase().contains(query.toLowerCase()) ||
          token.symbol.toLowerCase().contains(query.toLowerCase())).toList();
    }
    
    return popularTokens;
  }

  // Validate contract address format
  bool isValidContractAddress(String address) {
    // Basic Ethereum address validation
    final regex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return regex.hasMatch(address);
  }

  // Clear all custom tokens (for testing)
  Future<void> clearAllTokens() async {
    print('TokenService: Clearing all tokens');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokensKey);
    await prefs.remove(_tokenBalancesKey);
    print('TokenService: All tokens cleared');
  }
}
