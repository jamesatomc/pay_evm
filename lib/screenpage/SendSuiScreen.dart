import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../sui/sui_wallet_service.dart';
import '../services/transaction_service.dart';
import '../services/token_service.dart';
import '../models/token_model.dart';
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
  final TokenService _tokenService = TokenService();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  // No gas controls in SUI UI as requested

  bool _isLoading = false;
  NetworkModel? _currentNetwork;
  double _balance = 0.0;
  List<CustomTokenModel> _tokens = [];
  CustomTokenModel? _selectedToken;
  double _selectedTokenBalance = 0.0;

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
      // Load tokens for this network (SUI native + any detected tokens)
      try {
        List<CustomTokenModel> tokens;
        if (network.id.toLowerCase().contains('sui')) {
          tokens = await _tokenService.getTokenBalances(widget.wallet, network.id);
        } else {
          tokens = await _tokenService.getAllTokens(network.id);
        }
        // If the token loader returned nothing, ensure at least the native SUI token is present
        if (tokens.isEmpty) {
          final nativeFallback = CustomTokenModel.native(
            name: network.name,
            symbol: network.currencySymbol,
            networkId: network.id,
            balance: bal,
            iconUrl: network.iconUrl,
          );
          tokens = [nativeFallback];
        }

        setState(() => _tokens = tokens);

        // Prefer native token as default selection
        final native = tokens.firstWhere((t) => t.isNative, orElse: () => tokens.first);
        setState(() => _selectedToken = native);
        await _updateSelectedTokenBalance();
      } catch (e) {
        print('Error loading tokens: $e');
      }
    } catch (e) {
      print('Error loading Sui network/balance: $e');
    }
  }

  Future<void> _updateSelectedTokenBalance() async {
    if (_selectedToken == null || _currentNetwork == null) return;
    try {
      if (_selectedToken!.isNative) {
        setState(() => _selectedTokenBalance = _balance);
        return;
      }

      // If on Sui network we loaded token balances already via getTokenBalances,
      // so use the value present in the model. Otherwise fall back to ERC-20 flow.
      if (_currentNetwork!.id.toLowerCase().contains('sui')) {
        setState(() => _selectedTokenBalance = _selectedToken!.balance);
        return;
      }

      final bal = await _tokenService.getTokenBalance(_selectedToken!.contractAddress, widget.wallet.address, _currentNetwork!.id);
      setState(() => _selectedTokenBalance = bal);
    } catch (e) {
      print('Error fetching selected token balance: $e');
      setState(() => _selectedTokenBalance = 0.0);
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

    if (_selectedToken == null) {
      _showError('No token selected');
      return;
    }

    if (amount > _selectedTokenBalance) {
      _showError('Insufficient balance');
      return;
    }

  // No gas budget input in UI; use provider defaults.

    setState(() => _isLoading = true);

    try {
      String txHash;
      if (_selectedToken!.isNative) {
        txHash = await _walletService.sendSui(
          fromAddress: widget.wallet.address,
          toAddress: _addressController.text.trim(),
          amount: amount,
          networkId: _currentNetwork?.id,
        );
      } else {
        // For Sui Move tokens we expect contractAddress to be the Move type
        txHash = await _walletService.sendSuiToken(
          fromAddress: widget.wallet.address,
          toAddress: _addressController.text.trim(),
          amount: amount,
          coinType: _selectedToken!.contractAddress,
          decimals: _selectedToken!.decimals,
          networkId: _currentNetwork?.id,
        );
      }

      // Save pending transaction locally
      final pendingTx = _transactionService.createPendingTransaction(
        hash: txHash,
        from: widget.wallet.address,
        to: _addressController.text.trim(),
        amount: amount,
        symbol: _selectedToken?.symbol ?? 'SUI',
        networkId: _currentNetwork?.id ?? 'sui',
        gasPrice: 0.0,
        tokenAddress: _selectedToken!.isNative ? null : _selectedToken!.contractAddress,
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
  // Use selected token balance as max (native or token)
  final max = (_selectedTokenBalance).clamp(0.0, _selectedTokenBalance);
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

            // Token selector
            if (_tokens.isNotEmpty) ...[
              DropdownButtonFormField<CustomTokenModel>(
                value: _selectedToken,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  border: OutlineInputBorder(),
                ),
                items: _tokens.map((t) => DropdownMenuItem(value: t, child: Text('${t.symbol} ${t.isNative ? '' : ''}'))).toList(),
                onChanged: (t) async {
                  setState(() => _selectedToken = t);
                  await _updateSelectedTokenBalance();
                },
              ),
              const SizedBox(height: 12),
            ],

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
                labelText: 'Amount (${_selectedToken?.symbol ?? 'SUI'})',
                border: const OutlineInputBorder(),
                helperText: 'Available: ${_selectedTokenBalance.toStringAsFixed(6)} ${_selectedToken?.symbol ?? 'SUI'}',
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
              label: _isLoading
                  ? Text('Sending ${_selectedToken?.symbol ?? '...'}')
                  : Text('Send ${_selectedToken?.symbol ?? 'SUI'}'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }
}
