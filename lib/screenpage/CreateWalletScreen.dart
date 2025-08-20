import 'package:flutter/material.dart';
import 'package:kanaripay/utils/custom_widgets.dart';
import 'package:kanaripay/screenpage/AppLockScreen.dart';
import '../services/wallet_service.dart';
import '../utils/app_theme.dart';
import '../main.dart';

class CreateWalletScreen extends StatefulWidget {
  final int initialTab;

  const CreateWalletScreen({super.key, this.initialTab = 0});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen>
    with TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();

  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  int _mnemonicWordCount = 0;
  int _selectedMnemonicLength = 12; // Default to 12 words
  bool _isSui = false; // false = EVM, true = Sui (non-EVM)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
// Set initial tab
    _tabController.index = widget.initialTab; // Set tab controller index
    _mnemonicController.addListener(_updateMnemonicWordCount);

    // Add animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  void _updateMnemonicWordCount() {
    final words = _mnemonicController.text.trim().split(' ');
    final filteredWords = words.where((word) => word.isNotEmpty).toList();
    setState(() {
      _mnemonicWordCount = filteredWords.length;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mnemonicController.dispose();
    _privateKeyController.dispose();
    _tabController.dispose();
    _walletService.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createNewWallet() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a wallet name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _walletService.createNewWallet(
        _nameController.text.trim(),
        wordCount: _selectedMnemonicLength,
        isSui: _isSui,
      );
      if (mounted) {
        // Navigate to security setup after wallet creation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AppLockScreen(
              onSuccess: () {
                // Navigate to the main screen to re-check authentication
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppInitializer(),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        );
        _showSuccess(
          'Wallet created successfully with $_selectedMnemonicLength-word mnemonic!',
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error creating wallet: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromMnemonic() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a wallet name');
      return;
    }

    if (_mnemonicController.text.trim().isEmpty) {
      _showError('Please enter a mnemonic phrase');
      return;
    }

    // Validate mnemonic phrase length
    final mnemonicWords = _mnemonicController.text.trim().split(' ');
    final filteredWords = mnemonicWords
        .where((word) => word.isNotEmpty)
        .toList();

    if (filteredWords.length != 12 && filteredWords.length != 24) {
      _showError(
        'Mnemonic phrase must contain exactly 12 or 24 words. Currently: ${filteredWords.length} words',
      );
      return;
    }

    // Additional validation for common issues
    final cleanMnemonic = filteredWords.join(' ').toLowerCase();
    if (cleanMnemonic.contains('  ') || cleanMnemonic.trim() != cleanMnemonic) {
      _showError('Please check for extra spaces in the mnemonic phrase');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _walletService.importWalletFromMnemonic(
        cleanMnemonic, // Use cleaned mnemonic
        _nameController.text.trim(),
        isSui: _isSui,
      );
      if (mounted) {
        // Navigate to security setup after wallet import
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AppLockScreen(
              onSuccess: () {
                // กลับไปที่หน้าหลักเพื่อให้ระบบตรวจสอบ authentication ใหม่
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppInitializer(),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        );
        _showSuccess(
          'Wallet imported successfully with ${filteredWords.length}-word mnemonic!',
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error importing wallet: $e';
        if (e.toString().contains('Invalid mnemonic')) {
          errorMessage =
              'Invalid mnemonic phrase. Please check the words and try again.';
        }
        _showError(errorMessage);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromPrivateKey() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter a wallet name');
      return;
    }

    if (_privateKeyController.text.trim().isEmpty) {
      _showError('Please enter a private key');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _walletService.importWalletFromPrivateKey(
        _privateKeyController.text.trim(),
        _nameController.text.trim(),
        isSui: _isSui,
      );
      if (mounted) {
        // Navigate to security setup after private key import
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AppLockScreen(
              onSuccess: () {
                // Navigate to the main screen to re-check authentication
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppInitializer(),
                  ),
                  (route) => false,
                );
              },
            ),
          ),
        );
        _showSuccess('Wallet imported successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error importing wallet: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Create Wallet'),
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
                // Use theme-aware background so it looks correct in dark mode
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).cardColor
                    : Colors.white,
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
                // Keep selected label visible (white text on colored indicator)
                labelColor: Colors.white,
                // Use theme text color for unselected labels so they remain readable
                unselectedLabelColor:
                    Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textSecondary,
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
                        Icon(Icons.add_circle_outline, size: 18),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Create',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download, size: 18),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Import',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.vpn_key, size: 18),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'PrivateKey',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                children: [
                  _buildCreateNewTab(),
                  _buildImportMnemonicTab(),
                  _buildImportPrivateKeyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateNewTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallet name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Wallet Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
            const SizedBox(height: 16),

            // Info card - show Sui-specific guidance when Sui is selected
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          _isSui ? 'Create New Sui Wallet' : 'Create New Wallet',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSui
                          ? '• This will generate a Sui-compatible mnemonic and keypair.\n'
                              '• Sui uses different signing schemes and address formats than EVM.\n'
                              '• Keep your mnemonic and private key secure; follow Sui best practices.'
                          : '• The system will automatically generate a mnemonic phrase for you\n'
                              '• Please keep the mnemonic phrase safe and secure\n'
                              '• Do not share the mnemonic phrase with anyone\n'
                              '• You can also import wallets with 24-word phrases',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mnemonic length selector - EVM shows options, Sui shows Sui-specific note
            _isSui
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Sui Mnemonic',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'A Sui-compatible mnemonic will be generated for you. Sui typically uses standard BIP39 mnemonics with Sui-specific derivation paths.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mnemonic Length',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<int>(
                                  title: const Text('12 words'),
                                  subtitle: const Text('Standard (128-bit)'),
                                  value: 12,
                                  groupValue: _selectedMnemonicLength,
                                  onChanged: (value) {
                                    setState(() => _selectedMnemonicLength = value!);
                                  },
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<int>(
                                  title: const Text('24 words'),
                                  subtitle: const Text('High Security (256-bit)'),
                                  value: 24,
                                  groupValue: _selectedMnemonicLength,
                                  onChanged: (value) {
                                    setState(() => _selectedMnemonicLength = value!);
                                  },
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

            const SizedBox(height: 24),

            // Network selector (EVM vs Sui)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('EVM'),
                    selected: !_isSui,
                    onSelected: (v) => setState(() => _isSui = !v ? true : false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Sui'),
                    selected: _isSui,
                    onSelected: (v) => setState(() => _isSui = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action button
            CustomButton(
              text: 'Create New Wallet ($_selectedMnemonicLength words)',
              onPressed: _isLoading ? null : _createNewWallet,
              isLoading: _isLoading,
              icon: Icons.add_circle_outline,
              backgroundColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportMnemonicTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallet name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Wallet Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
            const SizedBox(height: 16),

            // Mnemonic input
            TextField(
              controller: _mnemonicController,
              decoration: InputDecoration(
                labelText: 'Mnemonic Phrase (12 or 24 words)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key),
                suffixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Chip(
                    label: Text(
                      '$_mnemonicWordCount words',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    backgroundColor: _mnemonicWordCount == 12 || _mnemonicWordCount == 24
                        ? Theme.of(context).primaryColor.withOpacity(0.12)
                        : _mnemonicWordCount > 0
                            ? Theme.of(context).colorScheme.error.withOpacity(0.12)
                            : Theme.of(context).cardColor,
                  ),
                ),
                helperText:
                    'Enter 12 or 24 word mnemonic phrase separated by spaces',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Info cards
            Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: AppTheme.primaryVariant, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Supported Formats:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSui
                          ? '• Sui-compatible mnemonics (BIP39) with Sui derivation paths\n'
                              '• Words must be separated by spaces\n'
                              '• Check spelling carefully before importing\n'
                              '• Example: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"'
                          : '• 12-word mnemonic phrase (BIP39)\n'
                              '• 24-word mnemonic phrase (BIP39)\n'
                              '• Words must be separated by spaces\n'
                              '• Check spelling carefully before importing\n'
                              '• Example: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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
                        _isSui ? 'Verify the Sui mnemonic and derivation before importing.' : 'Please verify the mnemonic phrase before proceeding',
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

            // Network selector (EVM vs Sui)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('EVM'),
                    selected: !_isSui,
                    onSelected: (v) => setState(() => _isSui = !v ? true : false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Sui'),
                    selected: _isSui,
                    onSelected: (v) => setState(() => _isSui = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action button
            CustomButton(
              text: 'Import from Mnemonic',
              onPressed: _isLoading ? null : _importFromMnemonic,
              isLoading: _isLoading,
              icon: Icons.download,
              backgroundColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportPrivateKeyTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallet name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Wallet Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
            ),
            const SizedBox(height: 16),

            // Private key input
            TextField(
              controller: _privateKeyController,
        decoration: InputDecoration(
        labelText: 'Private Key',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock),
        helperText: _isSui
          ? 'Enter Sui private key or seed (follow Sui format)'
          : 'Enter Private Key (can start with 0x or not)',
        ),
              obscureText: true,
            ),
            const SizedBox(height: 16),

            // Warning card
            Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.errorColor.withOpacity(0.15)
                  : AppTheme.errorColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.security, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Private Key is very important information. Do not share it with anyone.',
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

            // Network selector (EVM vs Sui)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('EVM'),
                    selected: !_isSui,
                    onSelected: (v) => setState(() => _isSui = !v ? true : false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Sui'),
                    selected: _isSui,
                    onSelected: (v) => setState(() => _isSui = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action button
            CustomButton(
              text: 'Import from Private Key',
              onPressed: _isLoading ? null : _importFromPrivateKey,
              isLoading: _isLoading,
              icon: Icons.vpn_key,
              backgroundColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
