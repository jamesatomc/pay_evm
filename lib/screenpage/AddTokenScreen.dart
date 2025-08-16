import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/token_service.dart';
import '../models/token_model.dart';
import '../models/network_model.dart';
import '../utils/app_theme.dart';
import '../utils/custom_widgets.dart';

class AddTokenScreen extends StatefulWidget {
  final NetworkModel network;
  
  const AddTokenScreen({
    super.key,
    required this.network,
  });

  @override
  State<AddTokenScreen> createState() => _AddTokenScreenState();
}

class _AddTokenScreenState extends State<AddTokenScreen> with TickerProviderStateMixin {
  final TokenService _tokenService = TokenService();
  late TabController _tabController;
  
  // Controllers for custom token form
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _symbolController = TextEditingController();
  final TextEditingController _decimalsController = TextEditingController(text: '18');
  
  // Search controller for popular tokens
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = false;
  bool _isValidating = false;
  List<CustomTokenModel> _popularTokens = [];
  List<CustomTokenModel> _filteredTokens = [];
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPopularTokens();
    _searchController.addListener(_onSearchChanged);
    
    // Add listeners to form fields to update state when they change
    _nameController.addListener(() => setState(() {}));
    _symbolController.addListener(() => setState(() {}));
    _decimalsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _addressController.dispose();
    _nameController.dispose();
    _symbolController.dispose();
    _decimalsController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularTokens() async {
    setState(() => _isLoading = true);
    try {
      final tokens = await _tokenService.searchPopularTokens(widget.network.id, '');
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
      _filteredTokens = _popularTokens.where((token) =>
          token.name.toLowerCase().contains(query) ||
          token.symbol.toLowerCase().contains(query)).toList();
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
      setState(() => _validationError = 'Invalid contract address format (must be 0x followed by 40 hex characters)');
      return;
    }

    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    try {
      final tokenInfo = await _tokenService.fetchTokenInfo(address, widget.network.id);
      if (tokenInfo != null) {
        // Auto-fill the form if we can fetch token info
        _nameController.text = tokenInfo.name.isNotEmpty ? tokenInfo.name : '';
        _symbolController.text = tokenInfo.symbol.isNotEmpty ? tokenInfo.symbol : '';
        _decimalsController.text = tokenInfo.decimals.toString();
        
        // Show success message when address is valid
        setState(() => _validationError = null);
        
        // Show snackbar to inform user they can now fill the form
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✓ Valid contract address. Please fill in token details.'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _validationError = 'Could not validate token address. Please check network connection.');
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

      print('AddTokenScreen: Attempting to add token ${token.symbol} to network ${token.networkId}');
      print('AddTokenScreen: Contract address: ${token.contractAddress}');

      final success = await _tokenService.addCustomToken(token);
      if (success) {
        if (mounted) {
          _showSuccess('Token "${token.symbol}" added successfully to ${widget.network.name}!');
          Navigator.pop(context, token);
        }
      } else {
        _showError('Failed to add token. It may already exist in this network (${widget.network.name}).');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text('Add Token to ${widget.network.name}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            margin: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              boxShadow: AppTheme.cardShadow,
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Popular Tokens'),
                Tab(text: 'Custom Token'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPopularTokensTab(),
                _buildCustomTokenTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularTokensTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        children: [
          // Search Bar
          TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tokens...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Token List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTokens.isEmpty
                    ? const EmptyState(
                        title: 'No Tokens Found',
                        subtitle: 'Try adjusting your search or add a custom token',
                        icon: Icons.search_off,
                      )
                    : ListView.builder(
                        itemCount: _filteredTokens.length,
                        itemBuilder: (context, index) {
                          final token = _filteredTokens[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                              boxShadow: AppTheme.cardShadow,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(AppTheme.spacingM),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                                ),
                                child: token.iconUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                                        child: Image.network(
                                          token.iconUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Icon(Icons.token, color: AppTheme.primaryColor),
                                        ),
                                      )
                                    : Icon(Icons.token, color: AppTheme.primaryColor),
                              ),
                              title: Text(
                                token.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                token.symbol,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _addPopularToken(token),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingM,
                                    vertical: AppTheme.spacingS,
                                  ),
                                ),
                                child: const Text('Add'),
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
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.warningColor,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Only add tokens from trusted sources. Verify contract addresses carefully.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Note: Same contract address can be added to different networks.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Example: 0xA0b86a33E6772e1622d7d9d4ce6d8D9Db8C8e5f4',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // Contract Address
          Text(
            'Token Contract Address',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppTheme.spacingS),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: 'Paste contract address (0x...)',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: _isValidating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _addressController.text.trim().isNotEmpty && _validationError == null
                      ? Icon(Icons.check_circle, color: AppTheme.successColor)
                      : Row(
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
                              tooltip: 'Paste from clipboard',
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: () {
                                // TODO: Implement QR code scanner
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('QR code scanner coming soon!'),
                                    backgroundColor: AppTheme.warningColor,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              tooltip: 'Scan QR code',
                            ),
                          ],
                        ),
              filled: true,
              fillColor: Colors.white,
              errorText: _validationError,
              helperText: _addressController.text.trim().isNotEmpty && _validationError == null 
                  ? 'Valid contract address ✓' 
                  : 'Enter a valid ERC-20 token contract address',
              helperStyle: TextStyle(
                color: _addressController.text.trim().isNotEmpty && _validationError == null 
                    ? AppTheme.successColor 
                    : AppTheme.textSecondary,
              ),
            ),
            onChanged: (_) => _validateTokenAddress(),
            maxLines: 1,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Token Name
          Text(
            'Token Name',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppTheme.spacingS),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g., USD Coin',
              prefixIcon: Icon(Icons.label_outline),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Token Symbol
          Text(
            'Token Symbol',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppTheme.spacingS),
          TextFormField(
            controller: _symbolController,
            decoration: const InputDecoration(
              hintText: 'e.g., USDC',
              prefixIcon: Icon(Icons.code),
              filled: true,
              fillColor: Colors.white,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Decimals
          Text(
            'Decimals',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppTheme.spacingS),
          TextFormField(
            controller: _decimalsController,
            decoration: const InputDecoration(
              hintText: '18',
              prefixIcon: Icon(Icons.precision_manufacturing),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          
          const Spacer(),
          
          // Add Button
          CustomButton(
            text: 'Add Token',
            onPressed: _canAddToken() ? _addCustomToken : null,
            isLoading: _isLoading,
            icon: Icons.add_circle_outline,
          ),
          
          const SizedBox(height: AppTheme.spacingM),
        ],
      ),
    );
  }
}
