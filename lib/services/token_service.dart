import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import '../models/token_model.dart';
import '../models/wallet_model.dart';
import 'network_service.dart';
import 'wallet_service.dart';
import 'price_service.dart';
import '../sui/sui_wallet_service.dart';

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

class TokenService {
  static const String _tokensKey = 'custom_tokens';
  static const String _tokenBalancesKey = 'token_balances';
  
  final NetworkService _networkService = NetworkService();
  final PriceService _priceService = PriceService();

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
      print('=== Fetching token info from contract ===');
      print('Contract: $contractAddress');
      print('Network: $networkId');
      
      final network = await _networkService.getNetworkById(networkId);
      if (network == null) {
        print('Network not found: $networkId');
        return null;
      }

      // Create Web3 client for this network
      final httpClient = JsonRpcClient();
      final web3client = Web3Client(network.rpcUrl, httpClient);
      
      try {
        final contractAddress_eth = EthereumAddress.fromHex(contractAddress);
        
        // Create ABI for standard ERC-20 functions
        final contract = DeployedContract(
          ContractAbi.fromJson(
            '''[
              {
                "constant": true,
                "inputs": [],
                "name": "name",
                "outputs": [{"name": "", "type": "string"}],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
              },
              {
                "constant": true,
                "inputs": [],
                "name": "symbol",
                "outputs": [{"name": "", "type": "string"}],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
              },
              {
                "constant": true,
                "inputs": [],
                "name": "decimals",
                "outputs": [{"name": "", "type": "uint8"}],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
              }
            ]''',
            'ERC20',
          ),
          contractAddress_eth,
        );
        
        // Get token name
        String tokenName = '';
        try {
          final nameFunction = contract.function('name');
          final nameResult = await web3client.call(
            contract: contract,
            function: nameFunction,
            params: [],
          );
          if (nameResult.isNotEmpty) {
            tokenName = nameResult.first as String;
          }
        } catch (e) {
          print('Could not get token name: $e');
        }
        
        // Get token symbol
        String tokenSymbol = '';
        try {
          final symbolFunction = contract.function('symbol');
          final symbolResult = await web3client.call(
            contract: contract,
            function: symbolFunction,
            params: [],
          );
          if (symbolResult.isNotEmpty) {
            tokenSymbol = symbolResult.first as String;
          }
        } catch (e) {
          print('Could not get token symbol: $e');
        }
        
        // Get token decimals
        int tokenDecimals = 18; // Default
        try {
          final decimalsFunction = contract.function('decimals');
          final decimalsResult = await web3client.call(
            contract: contract,
            function: decimalsFunction,
            params: [],
          );
          if (decimalsResult.isNotEmpty) {
            tokenDecimals = (decimalsResult.first as BigInt).toInt();
          }
        } catch (e) {
          print('Could not get token decimals, using default 18: $e');
        }
        
        print('Token info fetched:');
        print('Name: $tokenName');
        print('Symbol: $tokenSymbol');
        print('Decimals: $tokenDecimals');
        print('=== Token info fetch completed ===');
        
        return CustomTokenModel(
          contractAddress: contractAddress,
          name: tokenName,
          symbol: tokenSymbol,
          decimals: tokenDecimals,
          networkId: networkId,
        );
        
      } finally {
        web3client.dispose();
      }
      
    } catch (e) {
      print('=== Token info fetch failed ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Contract: $contractAddress');
      print('Network: $networkId');
      print('=== End token info error ===');
      
      // Return a basic model that user can fill manually
      return CustomTokenModel(
        contractAddress: contractAddress,
        name: '', // Will be filled by user
        symbol: '', // Will be filled by user
        decimals: 18, // Default, can be changed by user
        networkId: networkId,
      );
    }
  }

  // Get token balance for a wallet
  Future<double> getTokenBalance(String contractAddress, String walletAddress, String networkId) async {
    try {
      print('=== Getting ERC-20 token balance ===');
      print('Contract: $contractAddress');
      print('Wallet: $walletAddress');
      print('Network: $networkId');
      
      final network = await _networkService.getNetworkById(networkId);
      if (network == null) {
        print('Network not found: $networkId');
        return 0.0;
      }

      // Create Web3 client for this network
      final httpClient = JsonRpcClient();
      final web3client = Web3Client(network.rpcUrl, httpClient);
      
      try {
        // Get token decimals first
        final token = await getCustomTokens(networkId);
        final currentToken = token.firstWhere(
          (t) => t.contractAddress.toLowerCase() == contractAddress.toLowerCase(),
          orElse: () => CustomTokenModel(
            contractAddress: contractAddress,
            name: '',
            symbol: '',
            decimals: 18, // Default decimals
            networkId: networkId,
          ),
        );
        
        // ERC-20 balanceOf function signature
        final contractAddress_eth = EthereumAddress.fromHex(contractAddress);
        final walletAddress_eth = EthereumAddress.fromHex(walletAddress);
        
        // Create simple ABI for balanceOf function
        final contract = DeployedContract(
          ContractAbi.fromJson(
            '''[
              {
                "constant": true,
                "inputs": [{"name": "account", "type": "address"}],
                "name": "balanceOf",
                "outputs": [{"name": "balance", "type": "uint256"}],
                "payable": false,
                "stateMutability": "view",
                "type": "function"
              }
            ]''',
            'ERC20',
          ),
          contractAddress_eth,
        );
        
        final balanceOfFunction = contract.function('balanceOf');
        
        final result = await web3client.call(
          contract: contract,
          function: balanceOfFunction,
          params: [walletAddress_eth],
        );
        
        if (result.isNotEmpty) {
          final balanceInWei = result.first as BigInt;
          final decimals = currentToken.decimals;
          final balance = balanceInWei.toDouble() / (BigInt.from(10).pow(decimals).toDouble());
          
          print('Token balance found: $balance');
          print('Balance in Wei: $balanceInWei');
          print('Decimals: $decimals');
          print('=== Token balance request completed ===');
          
          return balance;
        }
        
        print('No balance result returned');
        return 0.0;
        
      } finally {
        web3client.dispose();
      }
      
    } catch (e) {
      print('=== Token balance request failed ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Contract: $contractAddress');
      print('Wallet: $walletAddress');
      print('=== End token balance error ===');
      return 0.0;
    }
  }

  // Get token balances for all tokens in a wallet
  Future<List<CustomTokenModel>> getTokenBalances(WalletModel wallet, String networkId) async {
    final tokensWithBalance = <CustomTokenModel>[];

    // If this is a Sui network, fetch Sui coin objects and map them to tokens
    if (networkId.toLowerCase().contains('sui')) {
      final suiService = SuiWalletService();

      try {
        // Ensure Sui client initialized for the network
        final ns = NetworkService();
        final n = await ns.getNetworkById(networkId) ?? await ns.getActiveNetwork();
        await suiService.initializeForNetwork(n);

        final coins = await suiService.getAllSuiCoins(wallet.address);

        // Aggregate balances by coin type
        final Map<String, BigInt> balanceByType = {};
        for (final c in coins) {
          try {
            dynamic coin = c;
            // Attempt common shapes
            String? type;
            dynamic balField;
            if (coin is Map) {
              type = coin['coinType'] ?? coin['type'] ?? coin['coin_type'] ?? coin['coinType'];
              balField = coin['balance'] ?? coin['value'] ?? coin['amount'] ?? coin['coinObject']['balance'];
            } else {
              // try dynamic access
              try {
                type = coin.coinType as String?;
              } catch (_) {}
              try {
                balField = coin.balance;
              } catch (_) {}
            }

            if (type == null) type = 'unknown';

            BigInt bal = BigInt.zero;
            if (balField is String) {
              bal = BigInt.tryParse(balField) ?? BigInt.zero;
            } else if (balField is int) {
              bal = BigInt.from(balField);
            } else if (balField is BigInt) {
              bal = balField;
            } else if (balField is num) {
              bal = BigInt.from(balField.toInt());
            }

            balanceByType[type] = (balanceByType[type] ?? BigInt.zero) + bal;
          } catch (e) {
            // ignore malformed coin entries
            print('Error parsing coin entry: $e');
          }
        }

        // Convert aggregated balances to CustomTokenModel list
        for (final entry in balanceByType.entries) {
          final type = entry.key;
          final total = entry.value;

          // Convert base units to human amount (1 SUI = 1e9)
          final double human = total.toDouble() / 1000000000.0;

          String symbol = type;
          String name = type;
          bool isNative = false;
          int decimals = 9;

          if (type.contains('sui::SUI') || type.toLowerCase().contains('::sui::sui')) {
            symbol = 'SUI';
            name = 'SUI';
            isNative = true;
            decimals = 9;
          } else {
            // Try to extract short symbol from Move type like '0x...::module::Name'
            final parts = type.split('::');
            if (parts.isNotEmpty) symbol = parts.last;
            name = symbol;
            isNative = false;
            decimals = 9; // Default for Sui tokens
          }

          final price = await _getTokenPrice(symbol);

          tokensWithBalance.add(CustomTokenModel(
            contractAddress: type,
            name: name,
            symbol: symbol,
            decimals: decimals,
            iconUrl: null,
            isNative: isNative,
            networkId: networkId,
            balance: human,
            price: price,
          ));
        }

        return tokensWithBalance;
      } catch (e) {
        print('Error fetching Sui coins: $e');
        return [];
      } finally {
        suiService.dispose();
      }
    }

    // Default: EVM-style tokens + native
    final tokens = await getAllTokens(networkId);

    for (final token in tokens) {
      double balance;
      if (token.isNative) {
        // For native tokens, get actual balance from WalletService
        final walletService = WalletService();
        try {
          balance = await walletService.getEthBalance(wallet.address);
        } catch (e) {
          print('Error getting native token balance: $e');
          balance = 0.0;
        } finally {
          walletService.dispose();
        }
      } else {
        balance = await getTokenBalance(token.contractAddress, wallet.address, networkId);
      }

      // Calculate USD price for the token using real-time prices
      double price = await _getTokenPrice(token.symbol);

      tokensWithBalance.add(token.copyWith(
        balance: balance,
        price: price,
      ));
    }

    return tokensWithBalance;
  }

  // Real-time token prices (API required)
  Future<double> _getTokenPrice(String symbol) async {
    try {
      return await _priceService.getTokenPrice(symbol);
    } catch (e) {
      print('Error getting price for $symbol: $e');
      // Return 0 if we can't get real price - better than fake prices
      return 0.0;
    }
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
