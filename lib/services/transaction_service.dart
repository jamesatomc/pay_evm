import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import '../models/transaction_model.dart';
import '../models/network_model.dart';
import 'network_service.dart';
import 'price_service.dart';

class TransactionService {
  static const String _transactionCacheKey = 'transaction_cache';
  static const String _localTransactionsKey = 'local_transactions';
  static const Duration _cacheTimeout = Duration(minutes: 5);
  
  final NetworkService _networkService = NetworkService();
  final PriceService _priceService = PriceService();
  final Map<String, List<TransactionModel>> _transactionCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Custom HTTP client for JSON-RPC
  http.Client _getHttpClient() {
    return http.Client();
  }

  // Get transaction history for a wallet on a specific network
  Future<List<TransactionModel>> getTransactionHistory({
    required String walletAddress,
    required String networkId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = '${walletAddress}_$networkId';
      
      // Check cache first (unless force refresh)
      if (!forceRefresh && _isValidCache(cacheKey)) {
        print('TransactionService: Using cached transactions for $cacheKey');
        return _transactionCache[cacheKey] ?? [];
      }

      print('TransactionService: Fetching transaction history for $walletAddress on $networkId');
      
      final network = await _networkService.getNetworkById(networkId);
      if (network == null) {
        print('TransactionService: Network not found: $networkId');
        return [];
      }

      List<TransactionModel> transactions = [];

      // Always try to get local transactions first
      final localTransactions = await _getLocalTransactions(walletAddress, networkId);
      transactions.addAll(localTransactions);

      // Try to fetch from blockchain explorer API
      try {
        final explorerTransactions = await _fetchFromExplorer(walletAddress, network, limit);
        
        // Merge with local transactions, avoiding duplicates
        for (final tx in explorerTransactions) {
          if (!transactions.any((localTx) => localTx.hash.toLowerCase() == tx.hash.toLowerCase())) {
            transactions.add(tx);
          }
        }
        
        print('TransactionService: Fetched ${explorerTransactions.length} transactions from explorer');
      } catch (e) {
        print('TransactionService: Explorer fetch failed: $e');
        // Continue with local transactions only
      }

      // Update cache
      _transactionCache[cacheKey] = transactions;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      // Save to persistent cache
      await _saveCacheToStorage();

      return transactions;
    } catch (e) {
      print('TransactionService: Error getting transaction history: $e');
      return [];
    }
  }

  // Fetch transactions from blockchain explorer API
  Future<List<TransactionModel>> _fetchFromExplorer(
    String walletAddress, 
    NetworkModel network, 
    int limit
  ) async {
    if (network.blockExplorerUrl == null || network.blockExplorerUrl!.isEmpty) {
      throw Exception('No block explorer URL available for ${network.name}');
    }

    String apiUrl;
    
    // Build API URL based on network
    if (network.blockExplorerUrl!.contains('etherscan')) {
      // Etherscan API
      final apiKey = await _getEtherscanApiKey();
      apiUrl = '${network.blockExplorerUrl}/api?module=account&action=txlist&address=$walletAddress&startblock=0&endblock=99999999&page=1&offset=$limit&sort=desc&apikey=$apiKey';
    } else if (network.blockExplorerUrl!.contains('bscscan')) {
      // BSCscan API
      final apiKey = await _getBscscanApiKey();
      apiUrl = '${network.blockExplorerUrl}/api?module=account&action=txlist&address=$walletAddress&startblock=0&endblock=99999999&page=1&offset=$limit&sort=desc&apikey=$apiKey';
    } else if (network.blockExplorerUrl!.contains('polygonscan')) {
      // Polygonscan API
      final apiKey = await _getPolygonscanApiKey();
      apiUrl = '${network.blockExplorerUrl}/api?module=account&action=txlist&address=$walletAddress&startblock=0&endblock=99999999&page=1&offset=$limit&sort=desc&apikey=$apiKey';
    } else {
      throw Exception('Unsupported explorer: ${network.blockExplorerUrl}');
    }

    final response = await http.get(Uri.parse(apiUrl));
    
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body);
    
    if (data['status'] != '1') {
      throw Exception('API Error: ${data['message']}');
    }

    final List<dynamic> txList = data['result'] ?? [];
    List<TransactionModel> transactions = [];

    for (var tx in txList) {
      try {
        final transaction = await _parseExplorerTransaction(tx, network, walletAddress);
        if (transaction != null) {
          transactions.add(transaction);
        }
      } catch (e) {
        print('TransactionService: Error parsing transaction ${tx['hash']}: $e');
      }
    }

    return transactions;
  }

  // Get locally stored transactions (from app's own transaction history)
  Future<List<TransactionModel>> _getLocalTransactions(String walletAddress, String networkId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localTxJson = prefs.getString(_localTransactionsKey);
      
      if (localTxJson == null) return [];
      
      final Map<String, dynamic> allLocalTx = json.decode(localTxJson);
      final walletKey = '${walletAddress.toLowerCase()}_$networkId';
      final List<dynamic> walletTxList = allLocalTx[walletKey] ?? [];
      
      return walletTxList.map((tx) => TransactionModel.fromJson(tx)).toList();
    } catch (e) {
      print('TransactionService: Error loading local transactions: $e');
      return [];
    }
  }

  // Save transaction locally when user makes a transaction
  Future<void> saveLocalTransaction(TransactionModel transaction, String walletAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localTxJson = prefs.getString(_localTransactionsKey) ?? '{}';
      final Map<String, dynamic> allLocalTx = json.decode(localTxJson);
      
      final walletKey = '${walletAddress.toLowerCase()}_${transaction.networkId}';
      final List<dynamic> walletTxList = allLocalTx[walletKey] ?? [];
      
      // Check if transaction already exists
      final exists = walletTxList.any((tx) => tx['hash'].toString().toLowerCase() == transaction.hash.toLowerCase());
      
      if (!exists) {
        walletTxList.insert(0, transaction.toJson()); // Add to beginning
        allLocalTx[walletKey] = walletTxList;
        
        await prefs.setString(_localTransactionsKey, json.encode(allLocalTx));
        print('TransactionService: Saved local transaction ${transaction.hash}');
        
        // Clear cache to force refresh
        final cacheKey = '${walletAddress}_${transaction.networkId}';
        _transactionCache.remove(cacheKey);
        _cacheTimestamps.remove(cacheKey);
      }
    } catch (e) {
      print('TransactionService: Error saving local transaction: $e');
    }
  }

  // Create a pending transaction record
  TransactionModel createPendingTransaction({
    required String hash,
    required String from,
    required String to,
    required double amount,
    required String symbol,
    required String networkId,
    required double gasPrice,
    String? tokenAddress,
  }) {
    return TransactionModel(
      hash: hash,
      from: from,
      to: to,
      amount: amount,
      symbol: symbol,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      status: TransactionStatus.pending,
      type: tokenAddress != null ? TransactionType.tokenTransfer : TransactionType.transfer,
      networkId: networkId,
      tokenAddress: tokenAddress,
      gasUsed: 21000, // Estimate
      gasPrice: gasPrice,
      gasFee: (21000 * gasPrice * 1e9) / 1e18, // Estimate in native token
      blockNumber: 0, // Will be updated when confirmed
      confirmations: 0,
    );
  }

  // Parse transaction from explorer API response
  Future<TransactionModel?> _parseExplorerTransaction(
    Map<String, dynamic> tx, 
    NetworkModel network, 
    String walletAddress
  ) async {
    try {
      final hash = tx['hash'] ?? '';
      final from = tx['from'] ?? '';
      final to = tx['to'] ?? '';
      final value = tx['value'] ?? '0';
      final timestamp = int.parse(tx['timeStamp'] ?? '0');
      final gasUsed = double.parse(tx['gasUsed'] ?? '0');
      final gasPrice = double.parse(tx['gasPrice'] ?? '0');
      final blockNumber = int.parse(tx['blockNumber'] ?? '0');
      final isError = tx['isError'] == '1';
      
      // Convert value from Wei to Ether
      final valueInWei = BigInt.parse(value);
      final amount = valueInWei.toDouble() / 1e18;
      
      // Calculate gas fee
      final gasFee = (gasUsed * gasPrice) / 1e18;
      
      // Determine transaction type and status
      final status = isError ? TransactionStatus.failed : TransactionStatus.confirmed;
      final type = _determineTransactionType(tx);
      
      // Get current price for USD value calculation
      double? usdValue;
      try {
        final tokenPrice = await _priceService.getTokenPrice(network.currencySymbol);
        usdValue = amount * tokenPrice;
      } catch (e) {
        print('TransactionService: Could not get USD value: $e');
      }

      // Get current block number to calculate confirmations
      int confirmations = 0;
      try {
        final client = _getHttpClient();
        final web3client = Web3Client(network.rpcUrl, client);
        final currentBlock = await web3client.getBlockNumber();
        confirmations = currentBlock - blockNumber;
        web3client.dispose();
        client.close();
      } catch (e) {
        print('TransactionService: Could not get confirmations: $e');
      }

      return TransactionModel(
        hash: hash,
        from: from,
        to: to,
        amount: amount,
        symbol: network.currencySymbol,
        usdValue: usdValue,
        timestamp: timestamp,
        status: status,
        type: type,
        networkId: network.id,
        tokenAddress: type == TransactionType.tokenTransfer ? tx['contractAddress'] : null,
        gasUsed: gasUsed,
        gasPrice: gasPrice / 1e9, // Convert to Gwei
        gasFee: gasFee,
        blockNumber: blockNumber,
        confirmations: confirmations,
        error: isError ? 'Transaction failed' : null,
      );
    } catch (e) {
      print('TransactionService: Error parsing transaction: $e');
      return null;
    }
  }

  // Determine transaction type based on transaction data
  TransactionType _determineTransactionType(Map<String, dynamic> tx) {
    final input = tx['input'] ?? '';
    final contractAddress = tx['contractAddress'] ?? '';
    
    // Check if it's a token transfer
    if (contractAddress.isNotEmpty) {
      return TransactionType.tokenTransfer;
    }
    
    // Check if it's a contract interaction
    if (input.isNotEmpty && input != '0x') {
      // Check for common method signatures
      if (input.startsWith('0xa9059cbb')) {
        return TransactionType.tokenTransfer; // ERC20 transfer
      } else if (input.startsWith('0x095ea7b3')) {
        return TransactionType.approval; // ERC20 approve
      } else {
        return TransactionType.contractInteraction;
      }
    }
    
    return TransactionType.transfer;
  }

  // Get transaction details by hash
  Future<TransactionModel?> getTransactionByHash(String txHash, String networkId) async {
    try {
      print('TransactionService: Getting transaction details for $txHash');
      
      final network = await _networkService.getNetworkById(networkId);
      if (network == null) return null;

      final client = _getHttpClient();
      final web3client = Web3Client(network.rpcUrl, client);
      
      try {
        final receipt = await web3client.getTransactionReceipt(txHash);
        final transaction = await web3client.getTransactionByHash(txHash);
        
        if (receipt == null || transaction == null) {
          return null;
        }

        // Convert transaction data
        final from = transaction.from.hex;
        final to = transaction.to?.hex ?? '';
        final value = transaction.value.getValueInUnit(EtherUnit.ether);
        final gasUsed = receipt.gasUsed?.toDouble() ?? 0;
        final gasPrice = transaction.gasPrice.getInWei.toDouble();
        final blockNumber = receipt.blockNumber.blockNum.toInt();
        final isSuccess = receipt.status ?? false;
        
        // Calculate gas fee
        final gasFee = (gasUsed * gasPrice) / 1e18;
        
        // Get current block for confirmations
        final currentBlock = await web3client.getBlockNumber();
        final confirmations = currentBlock - blockNumber;

        // Get USD value
        double? usdValue;
        try {
          final tokenPrice = await _priceService.getTokenPrice(network.currencySymbol);
          usdValue = value * tokenPrice;
        } catch (e) {
          print('TransactionService: Could not get USD value: $e');
        }

        return TransactionModel(
          hash: txHash,
          from: from,
          to: to,
          amount: value,
          symbol: network.currencySymbol,
          usdValue: usdValue,
          timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Approximate
          status: isSuccess ? TransactionStatus.confirmed : TransactionStatus.failed,
          type: TransactionType.transfer,
          networkId: networkId,
          gasUsed: gasUsed,
          gasPrice: gasPrice / 1e9, // Convert to Gwei
          gasFee: gasFee,
          blockNumber: blockNumber,
          confirmations: confirmations,
        );
      } finally {
        web3client.dispose();
        client.close();
      }
    } catch (e) {
      print('TransactionService: Error getting transaction by hash: $e');
      return null;
    }
  }

  // Check if cache is valid
  bool _isValidCache(String cacheKey) {
    if (!_transactionCache.containsKey(cacheKey) || !_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }
    
    final cacheTime = _cacheTimestamps[cacheKey]!;
    return DateTime.now().difference(cacheTime) < _cacheTimeout;
  }

  // Save cache to persistent storage
  Future<void> _saveCacheToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = <String, dynamic>{};
      
      _transactionCache.forEach((key, transactions) {
        cacheData[key] = {
          'transactions': transactions.map((tx) => tx.toJson()).toList(),
          'timestamp': _cacheTimestamps[key]?.millisecondsSinceEpoch ?? 0,
        };
      });
      
      await prefs.setString(_transactionCacheKey, json.encode(cacheData));
    } catch (e) {
      print('TransactionService: Error saving cache: $e');
    }
  }

  // Load cache from persistent storage
  Future<void> loadCacheFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(_transactionCacheKey);
      
      if (cacheString == null) return;
      
      final cacheData = json.decode(cacheString) as Map<String, dynamic>;
      
      cacheData.forEach((key, data) {
        final transactions = (data['transactions'] as List)
            .map((tx) => TransactionModel.fromJson(tx))
            .toList();
        final timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp']);
        
        _transactionCache[key] = transactions;
        _cacheTimestamps[key] = timestamp;
      });
      
      print('TransactionService: Loaded cache for ${cacheData.length} wallets');
    } catch (e) {
      print('TransactionService: Error loading cache: $e');
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    _transactionCache.clear();
    _cacheTimestamps.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transactionCacheKey);
  }

  // Get API keys (these should be stored securely or configured)
  Future<String> _getEtherscanApiKey() async {
    // In production, store this securely
    return 'YourEtherscanApiKey'; // Replace with actual key
  }

  Future<String> _getBscscanApiKey() async {
    // In production, store this securely
    return 'YourBscscanApiKey'; // Replace with actual key
  }

  Future<String> _getPolygonscanApiKey() async {
    // In production, store this securely
    return 'YourPolygonscanApiKey'; // Replace with actual key
  }

  // Refresh transaction status for pending transactions
  Future<TransactionModel?> refreshTransactionStatus(TransactionModel transaction) async {
    if (transaction.status.isCompleted) {
      return transaction; // Already completed
    }

    try {
      final updatedTx = await getTransactionByHash(transaction.hash, transaction.networkId);
      return updatedTx ?? transaction;
    } catch (e) {
      print('TransactionService: Error refreshing transaction status: $e');
      return transaction;
    }
  }

  // Watch for pending transactions and update them
  Stream<TransactionModel> watchTransaction(String txHash, String networkId) async* {
    TransactionModel? transaction;
    
    while (transaction?.status.isCompleted != true) {
      try {
        transaction = await getTransactionByHash(txHash, networkId);
        if (transaction != null) {
          yield transaction;
          
          if (transaction.status.isCompleted) {
            break;
          }
        }
        
        // Wait before next check
        await Future.delayed(const Duration(seconds: 10));
      } catch (e) {
        print('TransactionService: Error watching transaction: $e');
        break;
      }
    }
  }
}
