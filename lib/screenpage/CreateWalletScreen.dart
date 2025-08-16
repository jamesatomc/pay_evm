import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';
import '../utils/app_theme.dart';
import '../utils/custom_widgets.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final wallet = await _walletService.createNewWallet(_nameController.text.trim());
      if (mounted) {
        Navigator.pop(context, wallet);
        _showSuccess('Wallet created successfully!');
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

    setState(() => _isLoading = true);

    try {
      final wallet = await _walletService.importWalletFromMnemonic(
        _mnemonicController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, wallet);
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
      final wallet = await _walletService.importWalletFromPrivateKey(
        _privateKeyController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, wallet);
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
              color: Colors.grey[200],
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
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _getActionCallback(),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(_getButtonText()),
          ),
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
                  '• The system will automatically generate a Mnemonic phrase for you\n'
                  '• Please keep the Mnemonic phrase safe\n'
                  '• Do not share the Mnemonic phrase with anyone',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
          decoration: const InputDecoration(
            labelText: 'Mnemonic Phrase (12 words)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
            helperText: 'Enter Mnemonic phrase separated by spaces',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Please verify the Mnemonic phrase before proceeding',
                    style: TextStyle(fontSize: 12),
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
          color: Colors.red[50],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.security, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Private Key is very important information. Do not share it with anyone.',
                    style: TextStyle(fontSize: 12),
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
        return 'Create New Wallet';
      case 1:
        return 'Import from Mnemonic';
      case 2:
        return 'Import from Private Key';
      default:
        return 'Proceed';
    }
  }
}
