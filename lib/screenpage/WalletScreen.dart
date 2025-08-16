import 'package:flutter/material.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  // Dummy data for wallet assets. In a real app, this would come from a service.
  final List<Map<String, dynamic>> _assets = [
    {
      'name': 'Ethereum',
      'symbol': 'ETH',
      'amount': 2.5,
      'usd_value': 4500.75,
      'icon': Icons.currency_bitcoin // Placeholder icon
    },
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

  // Calculate total balance
  double get _totalBalance =>
      _assets.fold(0.0, (sum, item) => sum + (item['usd_value'] as double));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanari Wallet'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // TODO: Implement QR code scanner
            },
          ),
        ],
      ),
      body: Padding(
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
            const Text('Total Balance', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('\$${_totalBalance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // A simplified address display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('0x1234...abcd', style: TextStyle(fontFamily: 'monospace')),
                IconButton(icon: const Icon(Icons.copy, size: 16), onPressed: () {
                  // TODO: Implement copy to clipboard
                }),
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
            onPressed: () {
              // TODO: Implement Send action
            },
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement Receive action
            },
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Receive'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetList() {
    return ListView.builder(
      itemCount: _assets.length,
      itemBuilder: (context, index) {
        final asset = _assets[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(child: Icon(asset['icon'])),
            title: Text(asset['name']),
            subtitle: Text('${asset['amount']} ${asset['symbol']}'),
            trailing: Text('\$${(asset['usd_value'] as double).toStringAsFixed(2)}'),
          ),
        );
      },
    );
  }
}
