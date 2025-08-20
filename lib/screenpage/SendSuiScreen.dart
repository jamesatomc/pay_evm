import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  bool _showScanner = false;
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
    if (_showScanner) {
      return _buildQRScanner();
    }

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
            // Balance card (shows selected token balance)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.wallet.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Balance: ${_selectedTokenBalance.toStringAsFixed(6)} ${_selectedToken?.symbol ?? 'SUI'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Token selector card (styled like SendScreen)
            if (_tokens.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.token,
                            color: Theme.of(context).primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Select Token',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withOpacity(0.03),
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CustomTokenModel>(
                            value: _selectedToken,
                            isExpanded: true,
                            hint: const Text('Select a token'),
                            onChanged: (CustomTokenModel? newToken) async {
                              if (newToken != null) {
                                setState(() => _selectedToken = newToken);
                                await _updateSelectedTokenBalance();
                              }
                            },
                            items: _tokens.map((token) {
                              return DropdownMenuItem<CustomTokenModel>(
                                value: token,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: token.isNative
                                            ? Theme.of(context).primaryColor.withOpacity(0.15)
                                            : Theme.of(context).cardColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Theme.of(context).primaryColor.withOpacity(0.18),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          token.symbol.toUpperCase(),
                                          style: TextStyle(
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            token.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            token.symbol,
                                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        token.balance.toStringAsFixed(6),
                                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Destination address
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
              ),
            ),

            const SizedBox(height: 16),

            // Amount field with MAX
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

            // Warning
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.warningColor.withOpacity(0.12)
                  : AppTheme.warningColor.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.warningColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please check the address and amount carefully. Once sent, it cannot be undone.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

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

  Widget _buildQRScanner() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _showScanner = false),
        ),
      ),
      body: MobileScanner(onDetect: _onQRCodeDetected),
    );
  }
}
