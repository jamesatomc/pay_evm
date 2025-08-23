import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../services/token_service.dart';
import '../services/price_service.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
import '../models/token_model.dart';
import '../utils/app_theme.dart';
import '../utils/custom_widgets.dart';
import 'CreateWalletScreen.dart';
import 'WalletListScreen.dart';
import 'SendScreen.dart';
import 'SendSuiScreen.dart';
import 'ReceiveScreen.dart';
import 'NetworkSelectionScreen.dart';
import 'AddTokenScreen.dart';
import 'SettingsScreen.dart';
import 'TransactionHistoryScreen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  final TokenService _tokenService = TokenService();
  final PriceService _priceService = PriceService();
  WalletModel? _currentWallet;
  NetworkModel? _currentNetwork;
  double _ethBalance = 0.0;
  double _suiBalance = 0.0;
  double _totalBalance = 0.0;
  bool _isLoading = true;
  List<CustomTokenModel> _tokens = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _walletService.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);

    try {
      print('=== Loading wallet data ===');
      final wallet = await _walletService.getActiveWallet();
      final network = await _walletService.getCurrentNetwork();

      print('Current network: ${network.name} (${network.id})');
      print('Chain ID: ${network.chainId}');
      print('RPC URL: ${network.rpcUrl}');

      if (wallet != null) {
        print(
          'Loading balance for wallet: ${wallet.address} on network: ${network.name}',
        );
        double balance = 0.0;
        if (network.id.toLowerCase().contains('sui')) {
          balance = await _walletService.getSuiBalance(wallet.address);
          await _walletService.getSuiCoinCount(wallet.address);
          setState(() {
            _suiBalance = balance;
          });
        } else {
          balance = await _walletService.getEthBalance(wallet.address);
          setState(() => _ethBalance = balance);
        }

        // Load tokens for this wallet and network
        final tokens = await _tokenService.getTokenBalances(wallet, network.id);

        print('Balance loaded: $balance ${network.currencySymbol}');
        print('Tokens loaded: ${tokens.length} tokens');
        setState(() {
          _currentWallet = wallet;
          _currentNetwork = network;
          // _ethBalance or _suiBalance already set above
          _tokens = tokens;
          _tokens = tokens;
        });

        // Calculate total balance with real-time prices
        try {
          final totalBalance = await _calculateTotalBalance();
          setState(() {
            _totalBalance = totalBalance;
          });
          print(
            'Total balance calculated: \$${_totalBalance.toStringAsFixed(2)}',
          );
        } catch (e) {
          print('Error calculating total balance: $e');
          setState(() {
            _totalBalance = 0.0; // Set to 0 if can't get real prices
          });
        }
      } else {
        print('No wallet found, setting network: ${network.name}');
        setState(() {
          _currentNetwork = network;
          _tokens = [];
          _totalBalance = 0.0;
        });
      }
      print('=== Wallet data loaded successfully ===');
    } catch (e) {
      print('Error loading wallet: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Calculate total balance including native token
  Future<double> _calculateTotalBalance() async {
    // Use current network's currency price (real-time prices)
    double nativeTokenPrice = await _getNativeTokenPrice();
    // Use SUI balance for Sui networks, otherwise use ETH/EVM native balance
    final isSui =
        _currentNetwork != null &&
        _currentNetwork!.id.toLowerCase().contains('sui');
    final nativeBalance = isSui ? _suiBalance : _ethBalance;
    double total = nativeBalance * nativeTokenPrice;

    // Add custom token values
    for (final token in _tokens) {
      if (!token.isNative) {
        total += token.usdValue;
      }
    }

    return total;
  }

  Future<double> _getNativeTokenPrice() async {
    if (_currentNetwork == null) return 0.0; // Return 0 if no network

    try {
      final symbol = _currentNetwork!.currencySymbol;
      final price = await _priceService.getTokenPrice(symbol);
      print('Price for $symbol: \$${price.toStringAsFixed(2)}');
      return price;
    } catch (e) {
      print('Error getting price for ${_currentNetwork!.currencySymbol}: $e');
      // Return 0 instead of fake prices
      return 0.0;
    }
  }

  Future<void> _openNetworkSelection() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const NetworkSelectionScreen()),
    );

    if (result == true) {
      // Force refresh network connection and reload wallet data
      setState(() {
        _isLoading = true;
        // Clear old data immediately to show loading state
        _ethBalance = 0.0;
        _tokens = [];
      });

      try {
        // Get the new network and switch to it
        final newNetwork = await _walletService.getCurrentNetwork();
        print('Switched to network: ${newNetwork.name}');

        // Update UI with new network info immediately
        setState(() {
          _currentNetwork = newNetwork;
        });

        // Reload all wallet data with new network
        await _loadWallet();
      } catch (e) {
        print('Error after network switch: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openCreateWallet() async {
    final result = await Navigator.push<WalletModel>(
      context,
      MaterialPageRoute(builder: (context) => const CreateWalletScreen()),
    );

    if (result != null) {
      await _loadWallet();
    }
  }

  Future<void> _openWalletList() async {
    final result = await Navigator.push<WalletModel>(
      context,
      MaterialPageRoute(builder: (context) => const WalletListScreen()),
    );

    if (result != null) {
      await _loadWallet();
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _copyAddress() {
    if (_currentWallet != null) {
      Clipboard.setData(ClipboardData(text: _currentWallet!.address));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Address copied to clipboard'),
          backgroundColor: AppTheme.secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
          ),
        ),
      );
    }
  }



  IconData _getNetworkIcon(NetworkModel network) {
    if (network.isCustom) return Icons.lan;
    if (network.isTestnet) return Icons.code;

    switch (network.id) {
      case 'sui-devnet':
      case 'sui-testnet':
      case 'sui-mainnet':
        return Icons
            .language; // placeholder for Sui - replace with custom icon if available
      case 'ethereum':
      case 'sepolia':
        return Icons.currency_bitcoin; // Use as Ethereum placeholder
      case 'bsc':
      case 'bsc-testnet':
        return Icons.account_balance;
      case 'polygon':
      case 'mumbai':
        return Icons.hexagon;
      case 'avalanche':
      case 'fuji':
        return Icons.ac_unit;
      case 'fantom':
      case 'fantom-testnet':
        return Icons.speed;
      case 'alpen-testnet':
        return Icons.currency_bitcoin; // Bitcoin icon for sBTC
      default:
        return Icons.link;
    }
  }

  Widget _buildNetworkIcon(NetworkModel network) {
    // If network has a custom icon URL, use it
    if (network.iconUrl != null && network.iconUrl!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            network.iconUrl!,
            width: 20,
            height: 20,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to default icon if URL fails
              return Icon(
                _getNetworkIcon(network),
                color: Theme.of(context).colorScheme.onPrimary,
                size: 20,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Default icon
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getNetworkIcon(network),
        color: Theme.of(context).colorScheme.onPrimary,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kanari Wallet'),
        backgroundColor: AppTheme.transparent,
        elevation: 0,
        leading: _currentNetwork != null
            ? IconButton(
                icon: _buildNetworkIcon(_currentNetwork!),
                onPressed: _openNetworkSelection,
                tooltip: _currentNetwork!.name,
              )
            : null,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.textPrimary,
            ),
            tooltip: 'Wallets',
            onSelected: (value) {
              if (value == 'list') {
                _openWalletList();
              } else if (value == 'create') {
                _openCreateWallet();
              }
            },
            itemBuilder: (BuildContext context) => [
              if (_currentWallet != null)
                PopupMenuItem<String>(
                  value: 'list',
                  child: Row(
                    children: [
                      Icon(Icons.list, color: AppTheme.textPrimary),
                      const SizedBox(width: 8),
                      const Text('My Wallets'),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                value: 'create',
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text('Create Wallet'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: AppTheme.textPrimary),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),

          const SizedBox(width: AppTheme.spacingS),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : _currentWallet == null
          ? _buildNoWalletState()
          : _buildWalletContent(),
    );
  }

  Widget _buildNoWalletState() {
    return EmptyState(
      title: 'Welcome to Kanari Wallet',
      subtitle:
          'Create your first wallet to get started with secure crypto transactions',
      icon: Icons.account_balance_wallet_outlined,
      buttonText: 'Create New Wallet',
      onButtonPressed: _openCreateWallet,
    );
  }

  Widget _buildWalletContent() {
    return RefreshIndicator(
      onRefresh: _loadWallet,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Balance Card
            BalanceCard(
              totalBalance:
                  (_currentNetwork != null &&
                              _currentNetwork!.id.toLowerCase().contains('sui')
                          ? _suiBalance
                          : _totalBalance)
                      .toStringAsFixed(2),
              currency:
                  (_currentNetwork != null &&
                      _currentNetwork!.id.toLowerCase().contains('sui'))
                  ? 'SUI'
                  : 'USD',
              walletName: _currentWallet?.name,
              walletAddress: _currentWallet?.address,
              networkName: _currentNetwork?.name,
              networkIcon: _currentNetwork != null
                  ? _getNetworkIcon(_currentNetwork!)
                  : null,
              onCopyAddress: _copyAddress,
              onNetworkTap: _openNetworkSelection,
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Action Buttons
            _buildActionButtons(),

            const SizedBox(height: AppTheme.spacingXL),

            // Assets Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Assets',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppTheme.textPrimary),
                ),
                TextButton.icon(
                  onPressed: _openAddTokenScreen,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Token'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingM),

            // Asset List
            _buildAssetList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ActionButton(
          label: 'Send',
          icon: Icons.arrow_upward_rounded,
          onPressed: _currentWallet != null ? _openSendScreen : null,
          backgroundColor: Theme.of(context).cardColor,
          iconColor: AppTheme.primaryColor,
        ),
        const SizedBox(width: AppTheme.spacingM),
        ActionButton(
          label: 'Receive',
          icon: Icons.arrow_downward_rounded,
          onPressed: _currentWallet != null ? _openReceiveScreen : null,
          backgroundColor: Theme.of(context).cardColor,
          iconColor: AppTheme.secondaryColor,
        ),
        const SizedBox(width: AppTheme.spacingM),
        ActionButton(
          label: 'History',
          icon: Icons.history,
          onPressed: _currentWallet != null ? _openTransactionHistory : null,
          backgroundColor: Theme.of(context).cardColor,
          iconColor: Theme.of(context).colorScheme.secondary,
        ),
      ],
    );
  }

  void _openSendScreen() {
    if (_currentWallet != null) {
      // Choose SUI UI for Sui networks, otherwise use EVM send UI
      final isSui =
          _currentNetwork != null &&
          _currentNetwork!.id.toLowerCase().contains('sui');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => isSui
              ? SendSuiScreen(wallet: _currentWallet!)
              : SendScreen(wallet: _currentWallet!),
        ),
      ).then((_) => _loadWallet()); // Refresh wallet after send
    }
  }

  void _openReceiveScreen() {
    if (_currentWallet != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiveScreen(wallet: _currentWallet!),
        ),
      );
    }
  }

  void _openTransactionHistory() {
    if (_currentWallet != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TransactionHistoryScreen(wallet: _currentWallet!),
        ),
      );
    }
  }

  Future<void> _openAddTokenScreen() async {
    if (_currentNetwork != null) {
      final result = await Navigator.push<CustomTokenModel>(
        context,
        MaterialPageRoute(
          builder: (context) => AddTokenScreen(network: _currentNetwork!),
        ),
      );

      if (result != null) {
        // Reload wallet to show the new token
        await _loadWallet();
      }
    }
  }

  Widget _buildAssetList() {
    if (_tokens.isEmpty) {
      return const EmptyState(
        title: 'No Assets Yet',
        subtitle: 'Your tokens will appear here once you receive them',
        icon: Icons.account_balance_wallet_outlined,
      );
    }

    return Column(
      children: _tokens.map((token) {
        return AssetListItem(
          name: token.name,
          symbol: token.symbol,
          amount: token.balance,
          usdValue: token.usdValue,
          iconUrl: token.iconUrl,
          icon: token.isNative && _currentNetwork != null
              ? _getNetworkIcon(_currentNetwork!)
              : Icons.token,
          onTap: () {
            // TODO: Show token details
            _showTokenDetails(token);
          },
        );
      }).toList(),
    );
  }

  void _showTokenDetails(CustomTokenModel token) {
    showModalBottomSheet(
      context: context,
  backgroundColor: AppTheme.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppTheme.borderRadiusLarge),
            topRight: Radius.circular(AppTheme.borderRadiusLarge),
          ),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // Token info
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(
                      AppTheme.borderRadiusSmall,
                    ),
                  ),
                  child: token.iconUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusSmall,
                          ),
                          child: Image.network(
                            token.iconUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.token, color: AppTheme.primaryColor),
                          ),
                        )
                      : Icon(
                          token.isNative && _currentNetwork != null
                              ? _getNetworkIcon(_currentNetwork!)
                              : Icons.token,
                          color: AppTheme.primaryColor,
                        ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        token.symbol,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Balance info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(
                  AppTheme.borderRadiusMedium,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${token.balance.toStringAsFixed(4)} ${token.symbol}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '\$${token.usdValue.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Actions
            if (!token.isNative) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _removeToken(token);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove Token'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _removeToken(CustomTokenModel token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Token'),
        content: Text(
          'Are you sure you want to remove ${token.symbol} from your wallet?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _tokenService.removeCustomToken(
        token.contractAddress,
        token.networkId,
      );

      if (success) {
        await _loadWallet(); // Reload to update the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${token.symbol} removed successfully'),
              backgroundColor: AppTheme.secondaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
