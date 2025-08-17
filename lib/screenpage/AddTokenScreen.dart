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
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Controllers for custom token form
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _decimalsController = TextEditingController(
    text: '18',
  );

  // Search controller for popular tokens
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isValidating = false;
  bool _showScanner = false;
  List<CustomTokenModel> _popularTokens = [];
  List<CustomTokenModel> _filteredTokens = [];
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _loadPopularTokens();
    _searchController.addListener(_onSearchChanged);

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
    _searchController.dispose();
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularTokens() async {
    setState(() => _isLoading = true);
    try {
      final tokens = await _tokenService.searchPopularTokens(
        widget.network.id,
        '',
      );
      setState(() {
        _popularTokens = tokens;
        _filteredTokens = tokens;
      });
    } catch (e) {
      print('Error loading popular tokens: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTokens = _popularTokens
          .where(
            (token) =>
                token.name.toLowerCase().contains(query) ||
                token.symbol.toLowerCase().contains(query),
          )
          .toList();
    });
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

  Future<void> _addPopularToken(CustomTokenModel token) async {
    setState(() => _isLoading = true);

    try {
      final success = await _tokenService.addCustomToken(token);
      if (success) {
        if (mounted) {
          Navigator.pop(context, token);
          _showSuccess('${token.symbol} added successfully!');
        }
      } else {
        _showError('Failed to add ${token.symbol}. It may already exist.');
      }
    } catch (e) {
      _showError('Error adding ${token.symbol}: $e');
    } finally {
      setState(() => _isLoading = false);
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
            const Text('Add Token'),
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Modern Tab Bar
            Container(
              margin: const EdgeInsets.all(AppTheme.spacingM),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                boxShadow: AppTheme.elevatedShadow,
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Popular'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Custom'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildPopularTokensTab(), _buildCustomTokenTab()],
              ),
            ),
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

  Widget _buildPopularTokensTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Column(
        children: [
          // Search Bar with modern styling
          Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingL),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              boxShadow: AppTheme.cardShadow,
            ),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tokens by name or symbol...',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(AppTheme.spacingL),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),

          // Token List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                        const SizedBox(height: AppTheme.spacingM),
                        Text(
                          'Loading popular tokens...',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : _filteredTokens.isEmpty
                ? const EmptyState(
                    title: 'No Tokens Found',
                    subtitle: 'Try adjusting your search or add a custom token',
                    icon: Icons.search_off,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingXL),
                    itemCount: _filteredTokens.length,
                    itemBuilder: (context, index) {
                      final token = _filteredTokens[index];
                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: AppTheme.spacingM,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppTheme.borderRadiusLarge,
                          ),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(
                            AppTheme.spacingL,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(
                                AppTheme.borderRadiusMedium,
                              ),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                              ),
                            ),
                            child: token.iconUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.borderRadiusMedium,
                                    ),
                                    child: Image.network(
                                      token.iconUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                            Icons.token,
                                            color: AppTheme.primaryColor,
                                          ),
                                    ),
                                  )
                                : Icon(
                                    Icons.token,
                                    color: AppTheme.primaryColor,
                                  ),
                          ),
                          title: Text(
                            token.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              token.symbol,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          trailing: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppTheme.borderRadiusSmall,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () => _addPopularToken(token),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingL,
                                  vertical: AppTheme.spacingM,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.borderRadiusSmall,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTokenTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning Card with better styling
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.warningColor.withOpacity(0.1),
                  AppTheme.warningColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusSmall,
                        ),
                      ),
                      child: Icon(
                        Icons.security,
                        color: AppTheme.warningColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Text(
                        'Security Notice',
                        style: TextStyle(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  '• Only add tokens from trusted sources\n'
                  '• Verify contract addresses carefully\n'
                  '• Same contract can exist on different networks',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          // Form Fields with modern styling
          _buildFormField(
            title: 'Token Contract Address',
            child: TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: '0x742d35Cc6265C0532c8b61F4b4F3...'.toLowerCase(),
                hintStyle: TextStyle(
                  color: AppTheme.textMuted,
                  fontFamily: 'monospace',
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.link,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                suffixIcon: _isValidating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _addressController.text.trim().isNotEmpty &&
                          _validationError == null
                    ? Icon(Icons.check_circle, color: AppTheme.successColor)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.content_paste),
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                'text/plain',
                              );
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
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                  borderSide: BorderSide(
                    color: _validationError != null
                        ? AppTheme.errorColor.withOpacity(0.3)
                        : _addressController.text.trim().isNotEmpty &&
                              _validationError == null
                        ? AppTheme.successColor.withOpacity(0.3)
                        : AppTheme.primaryColor.withOpacity(0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                errorText: _validationError,
                helperText:
                    _addressController.text.trim().isNotEmpty &&
                        _validationError == null
                    ? '✓ Valid contract address'
                    : 'Enter ERC-20 token contract address',
                helperStyle: TextStyle(
                  color:
                      _addressController.text.trim().isNotEmpty &&
                          _validationError == null
                      ? AppTheme.successColor
                      : AppTheme.textSecondary,
                ),
              ),
              onChanged: (_) => _validateTokenAddress(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ),

          const SizedBox(height: AppTheme.spacingXL),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildFormField(
                  title: 'Token Name',
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., USD Coin',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.label_outline,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusMedium,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildFormField(
                  title: 'Symbol',
                  child: TextFormField(
                    controller: _symbolController,
                    decoration: InputDecoration(
                      hintText: 'USDC',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.code,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusMedium,
                        ),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusMedium,
                        ),
                        borderSide: BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingXL),

          _buildFormField(
            title: 'Decimals',
            child: TextFormField(
              controller: _decimalsController,
              decoration: InputDecoration(
                hintText: '18',
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.precision_manufacturing,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
                helperText: 'Usually 18 for most ERC-20 tokens',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),

          const SizedBox(height: AppTheme.spacingXXL),

          // Add Button
          CustomButton(
            text: 'Add Token to ${widget.network.name}',
            onPressed: _canAddToken() ? _addCustomToken : null,
            isLoading: _isLoading,
            icon: Icons.add_circle_outline,
            backgroundColor: AppTheme.primaryColor,
          ),

          const SizedBox(height: AppTheme.spacingL),
        ],
      ),
    );
  }

  Widget _buildFormField({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        child,
      ],
    );
  }
}
