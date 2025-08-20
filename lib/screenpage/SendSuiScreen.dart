import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../sui/sui_wallet_service.dart';
import '../services/transaction_service.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
import '../utils/app_theme.dart';
import 'PinVerificationScreen.dart';

class SendSuiScreen extends StatefulWidget {
  final WalletModel wallet;
  final String? initialAddress;
  final double? initialAmount;

  const SendSuiScreen({
    super.key,
    required this.wallet,
    this.initialAddress,
    this.initialAmount,
  });

  @override
  State<SendSuiScreen> createState() => _SendSuiScreenState();
}

class _SendSuiScreenState extends State<SendSuiScreen> {
  final SuiWalletService _walletService = SuiWalletService();
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  // No gas controls in SUI UI as requested

  bool _isLoading = false;
  NetworkModel? _currentNetwork;
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadNetworkAndBalance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefill address/amount if provided when pushed from other screens
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressController.text = widget.initialAddress!;
    }
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toStringAsFixed(6);
    }
  }

  Future<void> _loadNetworkAndBalance() async {
    try {
      final network = await _walletService.getCurrentNetwork();
      setState(() => _currentNetwork = network);
      final bal = await _walletService.getSuiBalance(widget.wallet.address);
      setState(() => _balance = bal);
    } catch (e) {
      print('Error loading Sui network/balance: $e');
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _walletService.dispose();
    super.dispose();
  }

  Future<bool> _verifyPinForTransaction() async {
    final LocalAuthentication auth = LocalAuthentication();
    bool didAuthenticate = false;

    try {
      didAuthenticate = await auth.authenticate(
        localizedReason: 'Authorize Transaction',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );
    } catch (e) {
      debugPrint('Biometric auth error: $e');
    }

    if (didAuthenticate) return true;

    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PinVerificationScreen(
            title: 'Authorize Transaction',
            subtitle: 'Enter your PIN to authorize this transaction',
            onPinVerified: (pin) => Navigator.pop(context, true),
            onCancel: () => Navigator.pop(context, false),
          ),
        ),
      );
      return result ?? false;
    } catch (e) {
      print('Error verifying PIN: $e');
      return false;
    }
  }

  Future<void> _sendSui() async {
    final pinVerified = await _verifyPinForTransaction();
    if (!pinVerified) return;

  if (_addressController.text.trim().isEmpty) {
      _showError('Please enter a destination address');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('Invalid amount');
      return;
    }

    if (amount > _balance) {
      _showError('Insufficient balance');
      return;
    }

  // No gas budget input in UI; use provider defaults.

    setState(() => _isLoading = true);

    try {
  final txHash = await _walletService.sendSui(
        fromAddress: widget.wallet.address,
        toAddress: _addressController.text.trim(),
        amount: amount,
        networkId: _currentNetwork?.id,
      );

      // Save pending transaction locally
      final pendingTx = _transactionService.createPendingTransaction(
        hash: txHash,
        from: widget.wallet.address,
        to: _addressController.text.trim(),
        amount: amount,
        symbol: 'SUI',
        networkId: _currentNetwork?.id ?? 'sui',
  gasPrice: 0.0,
        tokenAddress: null,
      );

      await _transactionService.saveLocalTransaction(pendingTx, widget.wallet.address);

      if (mounted) {
        Navigator.pop(context);
        _showSuccess('Transaction submitted\nTx: $txHash');
      }
    } catch (e) {
      if (mounted) _showError('Error sending SUI: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setMaxAmount() {
    // Use full balance as max; reserve tiny amount for gas if desired
    final max = (_balance).clamp(0.0, _balance);
    _amountController.text = max.toStringAsFixed(6);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.secondaryColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Send SUI'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.wallet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Balance: ${_balance.toStringAsFixed(6)} SUI'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Destination Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (SUI)',
                border: const OutlineInputBorder(),
                helperText: 'Available: ${_balance.toStringAsFixed(6)} SUI',
                suffixIcon: TextButton(
                  onPressed: _setMaxAmount,
                  child: const Text('MAX'),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),

            const SizedBox(height: 16),

            // Gas budget removed from SUI UI by request

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendSui,
              icon: const Icon(Icons.send),
              label: _isLoading ? const Text('Sending...') : const Text('Send SUI'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
