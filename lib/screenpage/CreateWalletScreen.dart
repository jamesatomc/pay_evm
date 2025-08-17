import 'package:flutter/material.dart';
import 'package:pay_evm/utils/custom_widgets.dart';
import '../services/wallet_service.dart';
import '../utils/app_theme.dart';
import 'SecuritySetupScreen.dart';
import '../main.dart';


class CreateWalletScreen extends StatefulWidget {
  final int initialTab;
  
  const CreateWalletScreen({super.key, this.initialTab = 0});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> with TickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mnemonicController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();
  
  late TabController _tabController;
  bool _isLoading = false;
  int _selectedTab = 0; // 0: Create, 1: Import Mnemonic, 2: Import Private Key
  int _mnemonicWordCount = 0;
  int _selectedMnemonicLength = 12; // Default to 12 words

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedTab = widget.initialTab; // Set initial tab
    _tabController.index = widget.initialTab; // Set tab controller index
    _mnemonicController.addListener(_updateMnemonicWordCount);
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
      );
      if (mounted) {
        // Navigate to security setup after wallet creation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SecuritySetupScreen(
              onSuccess: () {
                // Navigate to the main screen to re-check authentication
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AppInitializer()),
                  (route) => false,
                );
              },
            ),
          ),
        );
        _showSuccess('Wallet created successfully with $_selectedMnemonicLength-word mnemonic!');
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
    final filteredWords = mnemonicWords.where((word) => word.isNotEmpty).toList();
    
    if (filteredWords.length != 12 && filteredWords.length != 24) {
      _showError('Mnemonic phrase must contain exactly 12 or 24 words. Currently: ${filteredWords.length} words');
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
      );
      if (mounted) {
        // Navigate to security setup after wallet import
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SecuritySetupScreen(
              onSuccess: () {
                // กลับไปที่หน้าหลักเพื่อให้ระบบตรวจสอบ authentication ใหม่
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AppInitializer()),
                  (route) => false,
                );
              },
            ),
          ),
        );
        _showSuccess('Wallet imported successfully with ${filteredWords.length}-word mnemonic!');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error importing wallet: $e';
        if (e.toString().contains('Invalid mnemonic')) {
          errorMessage = 'Invalid mnemonic phrase. Please check the words and try again.';
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
      );
      if (mounted) {
        // Navigate to security setup after private key import
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SecuritySetupScreen(
              onSuccess: () {
                // Navigate to the main screen to re-check authentication
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AppInitializer()),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Wallet'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Create New',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 0 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Mnemonic',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 1 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedTab == 2 ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Private Key',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _selectedTab == 2 ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wallet name field (common for all tabs)
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Wallet Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
        ),
        const SizedBox(height: 16),
        
        // Tab-specific content
        if (_selectedTab == 0) _buildCreateNewTab(),
        if (_selectedTab == 1) _buildImportMnemonicTab(),
        if (_selectedTab == 2) _buildImportPrivateKeyTab(),
        
        const Spacer(),
        
        // Action button
        CustomButton(
          text: _getButtonText(),
          onPressed: _isLoading ? null : _getActionCallback(),
          isLoading: _isLoading,
          icon: _selectedTab == 0 ? Icons.add_circle_outline : 
                _selectedTab == 1 ? Icons.download : Icons.vpn_key,
          backgroundColor: AppTheme.primaryColor,
        ),
      ],
    );
  }

  Widget _buildCreateNewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    const Text(
                      'Create New Wallet',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• The system will automatically generate a mnemonic phrase for you\n'
                  '• Please keep the mnemonic phrase safe and secure\n'
                  '• Do not share the mnemonic phrase with anyone\n'
                  '• You can also import wallets with 24-word phrases',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Mnemonic length selector
        Card(
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
      ],
    );
  }

  Widget _buildImportMnemonicTab() {
    return Column(
      children: [
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
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: _mnemonicWordCount == 12 || _mnemonicWordCount == 24
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : _mnemonicWordCount > 0
                        ? Theme.of(context).colorScheme.error.withOpacity(0.1)
                        : Theme.of(context).cardColor,
              ),
            ),
            helperText: 'Enter 12 or 24 word mnemonic phrase separated by spaces',
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Supported Formats:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• 12-word mnemonic phrase (BIP39)\n'
                  '• 24-word mnemonic phrase (BIP39)\n'
                  '• Words must be separated by spaces\n'
                  '• Check spelling carefully before importing\n'
                  '• Example: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"',
                  style: TextStyle(fontSize: 12),
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
                Icon(
                  Icons.warning, 
                  color: AppTheme.warningColor, 
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please verify the mnemonic phrase before proceeding',
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
      ],
    );
  }

  Widget _buildImportPrivateKeyTab() {
    return Column(
      children: [
        TextField(
          controller: _privateKeyController,
          decoration: const InputDecoration(
            labelText: 'Private Key',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
            helperText: 'Enter Private Key (can start with 0x or not)',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.errorColor.withOpacity(0.15)
              : AppTheme.errorColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.security, 
                  color: AppTheme.errorColor, 
                  size: 20,
                ),
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
      ],
    );
  }

  VoidCallback? _getActionCallback() {
    switch (_selectedTab) {
      case 0:
        return _createNewWallet;
      case 1:
        return _importFromMnemonic;
      case 2:
        return _importFromPrivateKey;
      default:
        return null;
    }
  }

  String _getButtonText() {
    switch (_selectedTab) {
      case 0:
        return 'Create New Wallet ($_selectedMnemonicLength words)';
      case 1:
        return 'Import from Mnemonic';
      case 2:
        return 'Import from Private Key';
      default:
        return 'Proceed';
    }
  }
}