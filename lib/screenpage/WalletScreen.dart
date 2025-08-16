import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
import '../utils/app_theme.dart';
import '../utils/custom_widgets.dart';
import 'CreateWalletScreen.dart';
import 'WalletListScreen.dart';
import 'SendScreen.dart';
import 'ReceiveScreen.dart';
import 'NetworkSelectionScreen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  WalletModel? _currentWallet;
  NetworkModel? _currentNetwork;
  double _ethBalance = 0.0;
  bool _isLoading = true;
  
  // Demo data for other assets
  final List<Map<String, dynamic>> _otherAssets = [
    // You can add more assets here
  ];

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
      final wallet = await _walletService.getActiveWallet();
      final network = await _walletService.getCurrentNetwork();
      
      if (wallet != null) {
        print('Loading balance for wallet: ${wallet.address} on network: ${network.name}');
        final balance = await _walletService.getEthBalance(wallet.address);
        print('Balance loaded: $balance ${network.currencySymbol}');
        setState(() {
          _currentWallet = wallet;
          _currentNetwork = network;
          _ethBalance = balance;
        });
      } else {
        print('No wallet found, setting network: ${network.name}');
        setState(() {
          _currentNetwork = network;
        });
      }
    } catch (e) {
      print('Error loading wallet: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Calculate total balance including native token
  double get _totalBalance {
    // Use current network's currency price (demo prices)
    double nativeTokenPrice = _getNativeTokenPrice();
    double total = _ethBalance * nativeTokenPrice;
    total += _otherAssets.fold(0.0, (sum, item) => sum + (item['usd_value'] as double));
    return total;
  }

  double _getNativeTokenPrice() {
    if (_currentNetwork == null) return 1800.0; // Default ETH price
    
    switch (_currentNetwork!.currencySymbol) {
      case 'ETH':
        return 1800.0;
      case 'BNB':
        return 220.0;
      case 'MATIC':
        return 0.8;
      case 'AVAX':
        return 25.0;
      case 'FTM':
        return 0.25;
      case 'sBTC':
        return 30000.0; // Signet BTC price similar to BTC
      default:
        return 1.0; // Default for unknown tokens
    }
  }

  Future<void> _openNetworkSelection() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const NetworkSelectionScreen()),
    );
    
    if (result == true) {
      await _loadWallet(); // Reload to update network and balance
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

  Color _getNetworkColor(NetworkModel network) {
    if (network.isCustom) return Colors.blue;
    if (network.isTestnet) return Colors.orange;
    
    switch (network.id) {
      case 'ethereum':
      case 'sepolia':
        return const Color(0xFF627EEA);
      case 'bsc':
      case 'bsc-testnet':
        return const Color(0xFFF3BA2F);
      case 'polygon':
      case 'mumbai':
        return const Color(0xFF8247E5);
      case 'avalanche':
      case 'fuji':
        return const Color(0xFFE84142);
      case 'fantom':
      case 'fantom-testnet':
        return const Color(0xFF1969FF);
      case 'alpen-testnet':
        return const Color(0xFFF7931A); // Bitcoin orange
      default:
        return Colors.grey;
    }
  }

  IconData _getNetworkIcon(NetworkModel network) {
    if (network.isCustom) return Icons.lan;
    if (network.isTestnet) return Icons.code;
    
    switch (network.id) {
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
          color: _getNetworkColor(network),
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
                color: Colors.white,
                size: 20,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white),
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
        color: _getNetworkColor(network),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getNetworkIcon(network),
        color: Colors.white,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Kanari Wallet'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentNetwork != null
            ? IconButton(
                icon: _buildNetworkIcon(_currentNetwork!),
                onPressed: _openNetworkSelection,
                tooltip: _currentNetwork!.name,
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.textPrimary,
            ),
            onPressed: _currentWallet != null ? _openWalletList : _openCreateWallet,
            tooltip: 'Wallets',
          ),
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: AppTheme.primaryColor,
            ),
            onPressed: _openCreateWallet,
            tooltip: 'Create Wallet',
          ),
          const SizedBox(width: AppTheme.spacingS),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _currentWallet == null
              ? _buildNoWalletState()
              : _buildWalletContent(),
    );
  }

  Widget _buildNoWalletState() {
    return EmptyState(
      title: 'Welcome to Kanari Wallet',
      subtitle: 'Create your first wallet to get started with secure crypto transactions',
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
              totalBalance: _totalBalance.toStringAsFixed(2),
              walletName: _currentWallet?.name,
              walletAddress: _currentWallet?.address,
              networkName: _currentNetwork?.name,
              networkIcon: _currentNetwork != null ? _getNetworkIcon(_currentNetwork!) : null,
              networkColor: _currentNetwork != null ? _getNetworkColor(_currentNetwork!) : null,
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Add token functionality
                  },
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
          backgroundColor: Colors.white,
          iconColor: AppTheme.primaryColor,
        ),
        const SizedBox(width: AppTheme.spacingM),
        ActionButton(
          label: 'Receive',
          icon: Icons.arrow_downward_rounded,
          onPressed: _currentWallet != null ? _openReceiveScreen : null,
          backgroundColor: Colors.white,
          iconColor: AppTheme.secondaryColor,
        ),


      ],
    );
  }

  void _openSendScreen() {
    if (_currentWallet != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SendScreen(wallet: _currentWallet!),
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

  Widget _buildAssetList() {
    // Combine native token with other assets
    final allAssets = [
      {
        'name': _currentNetwork?.name ?? 'Ethereum',
        'symbol': _currentNetwork?.currencySymbol ?? 'ETH',
        'amount': _ethBalance,
        'usd_value': _ethBalance * _getNativeTokenPrice(),
        'icon': _currentNetwork != null ? _getNetworkIcon(_currentNetwork!) : Icons.currency_bitcoin
      },
      ..._otherAssets,
    ];

    if (allAssets.isEmpty) {
      return const EmptyState(
        title: 'No Assets Yet',
        subtitle: 'Your tokens will appear here once you receive them',
        icon: Icons.account_balance_wallet_outlined,
      );
    }

    return Column(
      children: allAssets.map((asset) {
        return AssetListItem(
          name: asset['name'],
          symbol: asset['symbol'],
          amount: asset['amount'] as double,
          usdValue: asset['usd_value'] as double,
          icon: asset['icon'] as IconData?,
          onTap: () {
            // TODO: Show asset details
          },
        );
      }).toList(),
    );
  }
}
