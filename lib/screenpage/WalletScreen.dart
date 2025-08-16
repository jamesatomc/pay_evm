import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
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
  
  // Dummy data for other assets
  final List<Map<String, dynamic>> _otherAssets = [

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
        final balance = await _walletService.getEthBalance(wallet.address);
        setState(() {
          _currentWallet = wallet;
          _currentNetwork = network;
          _ethBalance = balance;
        });
      } else {
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

  // Calculate total balance including ETH
  double get _totalBalance {
    double total = _ethBalance * 1800; // Assume ETH price $1800 for demo
    total += _otherAssets.fold(0.0, (sum, item) => sum + (item['usd_value'] as double));
    return total;
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
        //eng
        const SnackBar(content: Text('Copied')),
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
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanari Wallet'),
        centerTitle: true,
        leading: _currentNetwork != null
            ? IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _getNetworkColor(_currentNetwork!),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNetworkIcon(_currentNetwork!),
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                onPressed: _openNetworkSelection,
                tooltip: _currentNetwork!.name,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: _currentWallet != null ? _openWalletList : _openCreateWallet,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openCreateWallet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentWallet == null
              ? _buildNoWalletState()
              : _buildWalletContent(),
    );
  }

  Widget _buildNoWalletState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No wallets yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by creating a new wallet',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openCreateWallet,
            icon: const Icon(Icons.add),
            label: const Text('Create New Wallet'),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 24),
          _buildActionButtons(),
          const SizedBox(height: 24),
          const Text('My Assets',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(child: _buildAssetList()),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Balance', style: TextStyle(fontSize: 16, color: Colors.grey)),
                Row(
                  children: [
                    if (_currentNetwork != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getNetworkColor(_currentNetwork!).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getNetworkColor(_currentNetwork!),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getNetworkIcon(_currentNetwork!),
                              size: 12,
                              color: _getNetworkColor(_currentNetwork!),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentNetwork!.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getNetworkColor(_currentNetwork!),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _currentWallet?.name ?? '',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('\$${_totalBalance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Wallet address display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentWallet != null 
                      ? '${_currentWallet!.address.substring(0, 6)}...${_currentWallet!.address.substring(_currentWallet!.address.length - 4)}'
                      : '0x0000...0000',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: _copyAddress,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentWallet != null ? () => _openSendScreen() : null,
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _currentWallet != null ? () => _openReceiveScreen() : null,
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Receive'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
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
    // Combine ETH with other assets
    final allAssets = [
      {
        'name': _currentNetwork?.name ?? 'Ethereum',
        'symbol': _currentNetwork?.currencySymbol ?? 'ETH',
        'amount': _ethBalance,
        'usd_value': _ethBalance * 1800, // Demo price
        'icon': Icons.currency_bitcoin
      },
      ..._otherAssets,
    ];

    return ListView.builder(
      itemCount: allAssets.length,
      itemBuilder: (context, index) {
        final asset = allAssets[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(child: Icon(asset['icon'])),
            title: Text(asset['name']),
            subtitle: Text('${(asset['amount'] as double).toStringAsFixed(4)} ${asset['symbol']}'),
            trailing: Text('\$${(asset['usd_value'] as double).toStringAsFixed(2)}'),
          ),
        );
      },
    );
  }
}
