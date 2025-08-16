import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../models/wallet_model.dart';
import 'CreateWalletScreen.dart';
import 'WalletListScreen.dart';
import 'SendScreen.dart';
import 'ReceiveScreen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService();
  WalletModel? _currentWallet;
  double _ethBalance = 0.0;
  bool _isLoading = true;
  
  // Dummy data for other assets
  final List<Map<String, dynamic>> _otherAssets = [
    {
      'name': 'Tether',
      'symbol': 'USDT',
      'amount': 1050.22,
      'usd_value': 1050.22,
      'icon': Icons.monetization_on_outlined
    },
    {
      'name': 'Kanari Token',
      'symbol': 'KNR',
      'amount': 15000.0,
      'usd_value': 300.0,
      'icon': Icons.token_outlined
    },
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
      if (wallet != null) {
        final balance = await _walletService.getEthBalance(wallet.address);
        setState(() {
          _currentWallet = wallet;
          _ethBalance = balance;
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
        const SnackBar(content: Text('คัดลอกที่อยู่แล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanari Wallet'),
        centerTitle: true,
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
            'ยังไม่มีกระเป๋า',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'เริ่มต้นโดยการสร้างกระเป๋าใหม่',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openCreateWallet,
            icon: const Icon(Icons.add),
            label: const Text('สร้างกระเป๋าใหม่'),
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
                Text(
                  _currentWallet?.name ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
        'name': 'Ethereum',
        'symbol': 'ETH',
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
