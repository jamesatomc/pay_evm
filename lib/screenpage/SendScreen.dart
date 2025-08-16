import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/wallet_service.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';

class SendScreen extends StatefulWidget {
  final WalletModel wallet;

  const SendScreen({super.key, required this.wallet});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final WalletService _walletService = WalletService();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _gasPriceController = TextEditingController();
  
  bool _isLoading = false;
  double _ethBalance = 0.0;
  bool _showScanner = false;
  NetworkModel? _currentNetwork;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadNetwork();
    _gasPriceController.text = '20'; // Default gas price in Gwei
  }

  Future<void> _loadNetwork() async {
    try {
      final network = await _walletService.getCurrentNetwork();
      setState(() => _currentNetwork = network);
    } catch (e) {
      print('Error loading network: $e');
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _gasPriceController.dispose();
    _walletService.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _walletService.getEthBalance(widget.wallet.address);
      setState(() => _ethBalance = balance);
    } catch (e) {
      print('Error loading balance: $e');
    }
  }

  Future<void> _sendTransaction() async {
    if (_addressController.text.trim().isEmpty) {
      //eng
      _showError('Please enter a destination address');
      return;
    }

    if (_amountController.text.trim().isEmpty) {
      _showError('Please enter an amount');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('Invalid amount');
      return;
    }

    if (amount > _ethBalance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gasPrice = double.tryParse(_gasPriceController.text.trim());
      final txHash = await _walletService.sendEth(
        fromAddress: widget.wallet.address,
        toAddress: _addressController.text.trim(),
        amount: amount,
        gasPrice: gasPrice != null ? gasPrice * 1e9 : null, // Convert Gwei to Wei
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Transaction successful!\nTx Hash: $txHash');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error sending transaction: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scanQRCode() {
    setState(() => _showScanner = true);
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        setState(() {
          _showScanner = false;
          _addressController.text = code;
        });
      }
    }
  }

  void _setMaxAmount() {
    // Set max amount minus estimated gas fee (0.001 ETH)
    final maxAmount = (_ethBalance - 0.001).clamp(0.0, _ethBalance);
    _amountController.text = maxAmount.toStringAsFixed(6);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showScanner) {
      return _buildQRScanner();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Balance card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          widget.wallet.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Balance: ${_ethBalance.toStringAsFixed(6)} ${_currentNetwork?.currencySymbol ?? 'ETH'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recipient address
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Destination Address',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanQRCode,
                ),
                helperText: '${_currentNetwork?.name ?? 'Ethereum'} Address (0x...)',
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Amount
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.monetization_on),
                suffixIcon: TextButton(
                  onPressed: _setMaxAmount,
                  child: const Text('MAX'),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            
            const SizedBox(height: 16),
            
            // Gas price
            TextField(
              controller: _gasPriceController,
              decoration: const InputDecoration(
                labelText: 'Gas Price (Gwei)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_gas_station),
                helperText: 'Gas Fee (Recommended 20-50 Gwei)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            
            const SizedBox(height: 24),
            
            // Warning
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Please check the address and amount carefully. Once sent, it cannot be undone.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Send button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendTransaction,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send Coin'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRScanner() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _showScanner = false),
        ),
      ),
      body: MobileScanner(
        onDetect: _onQRCodeDetected,
      ),
    );
  }
}
