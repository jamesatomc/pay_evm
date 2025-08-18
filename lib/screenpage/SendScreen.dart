import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pay_evm/utils/custom_widgets.dart';
import 'package:local_auth/local_auth.dart';
import '../services/wallet_service.dart';
import '../services/token_service.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
import '../models/token_model.dart';
import '../utils/app_theme.dart';
import 'PinVerificationScreen.dart';

const double DEFAULT_MIN_GAS_PRICE = 0.1; // More flexible minimum
const double DEFAULT_MAX_GAS_PRICE = 100.0; // Higher maximum for flexibility

class SendScreen extends StatefulWidget {
  final WalletModel wallet;

  const SendScreen({super.key, required this.wallet});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final WalletService _walletService = WalletService();
  final TokenService _tokenService = TokenService();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _gasPriceController = TextEditingController();

  bool _isLoading = false;
  bool _showScanner = false;
  NetworkModel? _currentNetwork;

  // Token selection
  List<CustomTokenModel> _availableTokens = [];
  CustomTokenModel? _selectedToken;
  double _selectedTokenBalance = 0.0;

  // Gas fee options (dynamic)
  List<Map<String, dynamic>> _gasFeeOptions = [];
  String _selectedGasFeeLabel = '';
  double _minGasPrice = 0.0;
  double _maxGasPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _loadNetwork();
    _loadTokens();
    // _gasPriceController.text = '0.4'; // Default gas price in Gwei
  }

  Future<void> _loadNetwork() async {
    try {
      final network = await _walletService.getCurrentNetwork();
      setState(() => _currentNetwork = network);
      await _loadGasFeeOptions(network);
    } catch (e) {
      print('Error loading network: $e');
    }
  }

  Future<void> _loadGasFeeOptions(NetworkModel network) async {
    try {
      // get gas price from network (e.g. min, max, suggest)
      final gasInfo = await _walletService.getGasInfo(network.id);
      // gasInfo = {'low': 0.4, 'medium': 1.1, 'high': 2.6, 'min': 0.4, 'max': 2.6}
      setState(() {
        _gasFeeOptions = [
          {'label': 'Low', 'value': gasInfo['low'] ?? gasInfo['min'] ?? 0.1},
          {'label': 'Medium', 'value': gasInfo['medium'] ?? 1.1},
          {'label': 'High', 'value': gasInfo['high'] ?? gasInfo['max'] ?? 2.6},
        ];
        _selectedGasFeeLabel = 'Medium';
        _minGasPrice = gasInfo['min'] ?? 0.1;
        _maxGasPrice = gasInfo['max'] ?? 100.0;
        _gasPriceController.text = (_gasFeeOptions.firstWhere(
          (opt) => opt['label'] == _selectedGasFeeLabel,
          orElse: () => _gasFeeOptions.isNotEmpty
              ? _gasFeeOptions.first
              : {'label': 'Medium', 'value': 1.1},
        )['value']).toString();
      });
    } catch (e) {
      print('Error loading gas info: $e');
      // fallback default
      setState(() {
        _gasFeeOptions = [
          {'label': 'Low', 'value': 0.1},
          {'label': 'Medium', 'value': 1.1},
          {'label': 'High', 'value': 2.6},
        ];
        _selectedGasFeeLabel = 'Medium';
        _minGasPrice = 0.1;
        _maxGasPrice = 100.0;
        _gasPriceController.text = '1.1';
      });
    }
  }

  Future<void> _loadTokens() async {
    try {
      final network = await _walletService.getCurrentNetwork();
      final tokens = await _tokenService.getTokenBalances(
        widget.wallet,
        network.id,
      );
      setState(() {
        _availableTokens = tokens;
        // Set native token as default
        _selectedToken = tokens.firstWhere(
          (token) => token.isNative,
          orElse: () => tokens.isNotEmpty
              ? tokens.first
              : CustomTokenModel.native(
                  name: 'Ethereum',
                  symbol: 'ETH',
                  networkId: network.id,
                ),
        );
        _updateSelectedTokenBalance();
      });
    } catch (e) {
      print('Error loading tokens: $e');
    }
  }

  Future<void> _updateSelectedTokenBalance() async {
    if (_selectedToken == null) return;

    try {
      if (_selectedToken!.isNative) {
        final balance = await _walletService.getEthBalance(
          widget.wallet.address,
        );
        setState(() => _selectedTokenBalance = balance);
      } else {
        final balance = await _tokenService.getTokenBalance(
          _selectedToken!.contractAddress,
          widget.wallet.address,
          _currentNetwork?.id ?? '',
        );
        setState(() => _selectedTokenBalance = balance);
      }
    } catch (e) {
      print('Error updating token balance: $e');
      setState(() => _selectedTokenBalance = 0.0);
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

  // Verify PIN or Biometric before transaction
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

    if (didAuthenticate) {
      return true;
    }

    // fallback to PIN if biometric fails or not available
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

  Future<void> _sendTransaction() async {
    // First verify PIN before proceeding with transaction
    final pinVerified = await _verifyPinForTransaction();
    if (!pinVerified) {
      return; // User cancelled or PIN verification failed
    }

    if (_selectedToken == null) {
      _showError('Please select a token');
      return;
    }

    if (_addressController.text.trim().isEmpty) {
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

    if (amount > _selectedTokenBalance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final gasPriceGwei = double.tryParse(_gasPriceController.text.trim());
      print('Gas price from UI: $gasPriceGwei Gwei');

      // Check that gasPrice is valid (just ensure it's a positive number)
      if (gasPriceGwei == null || gasPriceGwei <= 0) {
        _showError('Gas price must be a positive number');
        setState(() => _isLoading = false);
        return;
      }

      // Show warning if gas price is very low or very high, but don't block the transaction
      if (gasPriceGwei < 0.1) {
        final shouldProceed = await _showWarningDialog(
          'Very Low Gas Price',
          'Gas price of $gasPriceGwei Gwei is very low. This may cause the transaction to take a long time to confirm or fail. Do you want to proceed?'
        );
        if (!shouldProceed) {
          setState(() => _isLoading = false);
          return;
        }
      } else if (gasPriceGwei > 100) {
        final shouldProceed = await _showWarningDialog(
          'Very High Gas Price',
          'Gas price of $gasPriceGwei Gwei is very high. This will result in high transaction fees. Do you want to proceed?'
        );
        if (!shouldProceed) {
          setState(() => _isLoading = false);
          return;
        }
      }

      String txHash;

      if (_selectedToken!.isNative) {
        // Send native token (ETH, BNB, etc.)
        txHash = await _walletService.sendEth(
          fromAddress: widget.wallet.address,
          toAddress: _addressController.text.trim(),
          amount: amount,
          gasPrice: gasPriceGwei,
          networkId: _currentNetwork?.id, // send networkId if necessary
        );
      } else {
        // Send ERC-20 token
        // TODO: Implement ERC-20 token transfer
        // For now, show a placeholder message
        throw Exception(
          'ERC-20 token transfers will be implemented in the next update',
        );
      }

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
    if (_selectedToken == null) return;

    // Set max amount minus estimated gas fee for native token
    double maxAmount;
    if (_selectedToken!.isNative) {
      maxAmount = (_selectedTokenBalance - 0.001).clamp(
        0.0,
        _selectedTokenBalance,
      );
    } else {
      maxAmount =
          _selectedTokenBalance; // For ERC-20 tokens, can send full amount
    }
    _amountController.text = maxAmount.toStringAsFixed(6);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<bool> _showWarningDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: AppTheme.warningColor),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Proceed'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_showScanner) {
      return _buildQRScanner();
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const Text('Send Money')],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
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
                      'Balance: ${_selectedTokenBalance.toStringAsFixed(6)} ${_selectedToken?.symbol ?? 'ETH'}',
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

            // Token selector
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.05),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CustomTokenModel>(
                          value: _selectedToken,
                          isExpanded: true,
                          hint: const Text('Select a token'),
                          onChanged: (CustomTokenModel? newToken) {
                            if (newToken != null) {
                              setState(() => _selectedToken = newToken);
                              _updateSelectedTokenBalance();
                            }
                          },
                          items: _availableTokens
                              .map<DropdownMenuItem<CustomTokenModel>>((
                                CustomTokenModel token,
                              ) {
                                return DropdownMenuItem<CustomTokenModel>(
                                  value: token,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: token.isNative
                                              ? Theme.of(
                                                  context,
                                                ).primaryColor.withOpacity(0.15)
                                              : Theme.of(
                                                  context,
                                                ).cardColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            token.symbol
                                                .substring(
                                                  0,
                                                  token.symbol.length > 2
                                                      ? 2
                                                      : token.symbol.length,
                                                )
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min, // Prevent overflow
                                          children: [
                                            Text(
                                              token.symbol,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              token.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.color,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          token.balance.toStringAsFixed(6),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              })
                              .toList(),
                        ),
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
                helperText:
                    '${_currentNetwork?.name ?? 'Ethereum'} Address (0x...)',
              ),
            ),

            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount (${_selectedToken?.symbol ?? 'ETH'})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.monetization_on),
                suffixIcon: TextButton(
                  onPressed: _setMaxAmount,
                  child: const Text('MAX'),
                ),
                helperText:
                    'Available: ${_selectedTokenBalance.toStringAsFixed(6)} ${_selectedToken?.symbol ?? 'ETH'}',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),

            const SizedBox(height: 16),

            // Gas Fee Selector
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.speed, size: 22, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    'Gas Fee',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedGasFeeLabel,
                      isExpanded: true,
                      underline: Container(),
                      items: _gasFeeOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option['label'],
                          child: Text(
                            '${option['label']} (${option['value']} Gwei)',
                          ),
                        );
                      }).toList(),
                      onChanged: (String? label) {
                        if (label != null) {
                          setState(() {
                            _selectedGasFeeLabel = label;
                            final selected = _gasFeeOptions.firstWhere(
                              (opt) => opt['label'] == label,
                              orElse: () => {'label': '', 'value': 0.0},
                            );
                            if (selected['label'] != '') {
                              _gasPriceController.text = selected['value']
                                  .toString();
                            }
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Gas price
            TextField(
              controller: _gasPriceController,
              decoration: InputDecoration(
                labelText: 'Gas Price (Gwei)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.local_gas_station),
                helperText:
                    'Recommended: ${_minGasPrice.toStringAsFixed(2)} - ${_maxGasPrice.toStringAsFixed(2)} Gwei (custom values allowed)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),

            const SizedBox(height: 24),

            // Warning
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.warningColor.withOpacity(0.15)
                  : AppTheme.warningColor.withOpacity(0.1),
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

            const SizedBox(height: 24),

            // Send button
            CustomButton(
              text: 'Send ${_selectedToken?.symbol ?? 'ETH'}',
              onPressed: _isLoading ? null : _sendTransaction,
              isLoading: _isLoading,
              icon: Icons.send,
              backgroundColor: AppTheme.primaryColor,
            ),

            const SizedBox(height: 24),
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
