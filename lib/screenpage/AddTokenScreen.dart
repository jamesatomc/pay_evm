import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/token_service.dart';
import '../models/token_model.dart';
import '../models/network_model.dart';
import '../utils/app_theme.dart';
import '../utils/custom_widgets.dart';

class AddTokenScreen extends StatefulWidget {
  final NetworkModel network;

  const AddTokenScreen({super.key, required this.network});

  @override
  State<AddTokenScreen> createState() => _AddTokenScreenState();
}

class _AddTokenScreenState extends State<AddTokenScreen>
    with TickerProviderStateMixin {
  final TokenService _tokenService = TokenService();
  late AnimationController _fadeController;

  // Controllers for custom token form
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _decimalsController = TextEditingController(
    text: '18',
  );

  bool _isLoading = false;
  bool _isValidating = false;
  bool _showScanner = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Add listeners to form fields to update state when they change
    _nameController.addListener(() => setState(() {}));
    _symbolController.addListener(() => setState(() {}));
    _decimalsController.addListener(() => setState(() {}));

    _fadeController.forward();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    _symbolController.dispose();
    _decimalsController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool _canAddToken() {
    return _addressController.text.trim().isNotEmpty &&
        _nameController.text.trim().isNotEmpty &&
        _symbolController.text.trim().isNotEmpty &&
        _decimalsController.text.trim().isNotEmpty &&
        _validationError == null &&
        !_isValidating &&
        !_isLoading;
  }

  Future<void> _validateTokenAddress() async {
    final address = _addressController.text.trim();

    if (address.isEmpty) {
      setState(() {
        _validationError = null;
        _nameController.clear();
        _symbolController.clear();
        _decimalsController.text = '18';
      });
      return;
    }

    if (!_tokenService.isValidContractAddress(address)) {
      setState(
        () => _validationError =
            'Invalid contract address format (must be 0x followed by 40 hex characters)',
      );
      return;
    }

    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    try {
      final tokenInfo = await _tokenService.fetchTokenInfo(
        address,
        widget.network.id,
      );
      if (tokenInfo != null) {
        // Auto-fill the form with fetched token info
        _nameController.text = tokenInfo.name.isNotEmpty ? tokenInfo.name : '';
        _symbolController.text = tokenInfo.symbol.isNotEmpty
            ? tokenInfo.symbol
            : '';
        _decimalsController.text = tokenInfo.decimals.toString();

        // Show success message when token info is fetched
        setState(() => _validationError = null);

        if (mounted) {
          if (tokenInfo.name.isNotEmpty && tokenInfo.symbol.isNotEmpty) {
            // Token info was successfully fetched
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✓ Token info loaded: ${tokenInfo.symbol} (${tokenInfo.name})',
                ),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            // Valid address but couldn't fetch full info
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '✓ Valid contract address. Please fill in token details manually.',
                ),
                backgroundColor: AppTheme.warningColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(
        () => _validationError =
            'Could not validate token address. Please check network connection.',
      );
      print('Error validating token: $e');
    } finally {
      setState(() => _isValidating = false);
    }
  }

  Future<void> _addCustomToken() async {
    if (!_canAddToken()) {
      _showError('Please fill in all required fields correctly');
      return;
    }

    final decimals = int.tryParse(_decimalsController.text.trim());
    if (decimals == null || decimals < 0 || decimals > 18) {
      _showError('Decimals must be a number between 0 and 18');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = CustomTokenModel(
        contractAddress: _addressController.text.trim(),
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim().toUpperCase(),
        decimals: decimals,
        networkId: widget.network.id,
      );

      print(
        'AddTokenScreen: Attempting to add token ${token.symbol} to network ${token.networkId}',
      );
      print('AddTokenScreen: Contract address: ${token.contractAddress}');

      final success = await _tokenService.addCustomToken(token);
      if (success) {
        if (mounted) {
          _showSuccess(
            'Token "${token.symbol}" added successfully to ${widget.network.name}!',
          );
          Navigator.pop(context, token);
        }
      } else {
        _showError(
          'Failed to add token. It may already exist in this network (${widget.network.name}).',
        );
      }
    } catch (e) {
      _showError('Error adding token: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.secondaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        ),
      ),
    );
  }

  void _scanQRCode() {
    setState(() => _showScanner = true);
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        // Clean the scanned result
        String cleanAddress = code.trim();

        // Handle different QR code formats
        if (cleanAddress.startsWith('ethereum:')) {
          // Extract address from ethereum URI format
          final uri = Uri.tryParse(cleanAddress);
          if (uri != null && uri.path.isNotEmpty) {
            cleanAddress = uri.path;
          }
        }

        setState(() {
          _showScanner = false;
          _addressController.text = cleanAddress;
        });

        // Validate the scanned address
        _validateTokenAddress();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✓ Address scanned: ${cleanAddress.substring(0, 10)}...${cleanAddress.substring(cleanAddress.length - 8)}',
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
          children: [
            const Text('Add Custom Token'),
            Text(
              widget.network.name,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Security Notice Card (เหมือน Warning Card ใน SendScreen)
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.warningColor.withOpacity(0.15)
                  : AppTheme.warningColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.security, color: AppTheme.warningColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only add tokens from trusted sources. Verify contract addresses carefully. Same contract can exist on different networks.',
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

            // Token Contract Address
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Token Contract Address',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          _addressController.text = data!.text!;
                          _validateTokenAddress();
                        }
                      },
                      tooltip: 'Paste',
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanQRCode,
                      tooltip: 'Scan QR',
                    ),
                  ],
                ),
                helperText: _validationError != null
                    ? _validationError
                    : (_addressController.text.trim().isNotEmpty
                        ? '✓ Valid contract address'
                        : 'Enter ERC-20 token contract address'),
                helperStyle: TextStyle(
                  color: _validationError != null
                      ? AppTheme.errorColor
                      : (_addressController.text.trim().isNotEmpty
                          ? AppTheme.successColor
                          : AppTheme.textSecondary),
                ),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              onChanged: (_) => _validateTokenAddress(),
            ),

            const SizedBox(height: 16),

            // Token Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Token Name',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label_outline),
                hintText: 'e.g., USD Coin',
              ),
            ),

            const SizedBox(height: 16),

            // Symbol
            TextField(
              controller: _symbolController,
              decoration: InputDecoration(
                labelText: 'Symbol',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.code),
                hintText: 'USDC',
              ),
              textCapitalization: TextCapitalization.characters,
            ),

            const SizedBox(height: 16),

            // Decimals
            TextField(
              controller: _decimalsController,
              decoration: InputDecoration(
                labelText: 'Decimals',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.precision_manufacturing),
                helperText: 'Usually 18 for most ERC-20 tokens',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),

            const SizedBox(height: 24),

            // Warning (เหมือน SendScreen)
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
                        'Please check the contract address and token details carefully. Once added, it cannot be undone.',
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

            // Add Button
            CustomButton(
              text: 'Add Token to ${widget.network.name}',
              onPressed: _canAddToken() ? _addCustomToken : null,
              isLoading: _isLoading,
              icon: Icons.add_circle_outline,
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Token Contract'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _showScanner = false),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onQRCodeDetected),
          // Overlay with scanning guide
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(
                  AppTheme.borderRadiusMedium,
                ),
              ),
              child: const Text(
                'Position the QR code within the frame to scan the token contract address',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }


}
