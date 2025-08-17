import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/wallet_service.dart';
import '../services/token_service.dart';
import '../models/wallet_model.dart';
import '../models/network_model.dart';
import '../models/token_model.dart';
import '../utils/app_theme.dart';
import 'PinVerificationScreen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadNetwork();
    _loadTokens();
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

  Future<void> _loadTokens() async {
    try {
      final network = await _walletService.getCurrentNetwork();
      final tokens = await _tokenService.getTokenBalances(widget.wallet, network.id);
      setState(() {
        _availableTokens = tokens;
        // Set native token as default
        _selectedToken = tokens.firstWhere(
          (token) => token.isNative,
          orElse: () => tokens.isNotEmpty ? tokens.first : CustomTokenModel.native(
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
        final balance = await _walletService.getEthBalance(widget.wallet.address);
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

  // Verify PIN before transaction
  Future<bool> _verifyPinForTransaction() async {
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
      
      String txHash;
      
      if (_selectedToken!.isNative) {
        // Send native token (ETH, BNB, etc.)
        txHash = await _walletService.sendEth(
          fromAddress: widget.wallet.address,
          toAddress: _addressController.text.trim(),
          amount: amount,
          gasPrice: gasPriceGwei,
        );
      } else {
        // Send ERC-20 token
        // TODO: Implement ERC-20 token transfer
        // For now, show a placeholder message
        throw Exception('ERC-20 token transfers will be implemented in the next update');
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
      maxAmount = (_selectedTokenBalance - 0.001).clamp(0.0, _selectedTokenBalance);
    } else {
      maxAmount = _selectedTokenBalance; // For ERC-20 tokens, can send full amount
    }
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Token',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
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
                          items: _availableTokens.map<DropdownMenuItem<CustomTokenModel>>((CustomTokenModel token) {
                            return DropdownMenuItem<CustomTokenModel>(
                              value: token,
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: token.isNative 
                                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                                          : Theme.of(context).cardColor.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        token.symbol.substring(0, token.symbol.length > 2 ? 2 : token.symbol.length).toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          token.symbol,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          token.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    token.balance.toStringAsFixed(6),
                                    style: const TextStyle(fontWeight: FontWeight.w500),
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
                labelText: 'Amount (${_selectedToken?.symbol ?? 'ETH'})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.monetization_on),
                suffixIcon: TextButton(
                  onPressed: _setMaxAmount,
                  child: const Text('MAX'),
                ),
                helperText: 'Available: ${_selectedTokenBalance.toStringAsFixed(6)} ${_selectedToken?.symbol ?? 'ETH'}',
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.warningColor.withOpacity(0.15)
                  : AppTheme.warningColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning, 
                      color: AppTheme.warningColor, 
                      size: 20,
                    ),
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
                    : Text('Send ${_selectedToken?.symbol ?? 'ETH'}'),
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
